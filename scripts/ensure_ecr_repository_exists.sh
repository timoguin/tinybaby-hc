# =====================================================================================
#
# Create and configure an ECR repository to share within an AWS Organization. If the
# repository doesn't exist, it will be created, and a repository policy that allows
# read access from any account that is a member of the specified AWS Organization. If
# the repository already exists, all operations are skipped.
#
# =====================================================================================
#
#!/bin/bash
set -eou pipefail

# Print a debug log message if verbose is set to 1
function print_dbg() {
  if [ $verbose -eq 1 ]; then
    printf "[%s] [DEBUG] %s\n" $(date -u +"%Y-%m-%dT%H:%M:%SZ") "$1" >&2
  fi
}

# Create the repository if it doesn't exist. Set a repository policy.
function create_repository_if_not_exists() {
  if [ "$org_id" == "" ]; then
    print_dbg "Organization ID not specified. Querying Organizations API"
    org_id=$(aws organizations describe-organization --query 'Organization.Id' --output text)
  fi

  print_dbg "Checking if repository $name exists"

  # Swallow output and assign the value of the exit code to the repo_exists variable if
  # it errors (the repo doesn't exist)
  repo_exists=0
  aws ecr describe-repositories --query 'repositories'         \
    | jq                                                       \
        --compact-output                                       \
        --exit-status                                          \
        --raw-output                                           \
        --arg name $name                                       \
        'map(select(.repositoryName == $name)) | length == 1'  \
        >/dev/null 2>&1                                        \
     && repo_exists=1

  if [ $repo_exists -eq 1 ]; then
    print_dbg "Repository $name already exists. Skipping creation"
  else
    print_dbg "Repository $name not found. Creating repository"

    # Combine the default "Name" tag with the TAGS_JSON env var
    tags_json=$(jq                   \
      --compact-output               \
      --null-input                   \
      --raw-output                   \
      --arg name $name               \
      --argjson tags ${TAGS_JSON-[]} \
      '[{Key: "Name", Value: $name}] + $tags | .[] | {(.Key): .Value} | to_entries[] | {Key: .key, Value: .value}' | jq --slurp)

    ecr_create_repository_input=$(jq                                \
      --compact-output                                              \
      --null-input                                                  \
      --raw-output                                                  \
      --arg repositoryName $name                                    \
      --arg imageTagMutability 'IMMUTABLE'                          \
      --argjson imageScanningConfiguration '{"scanOnPush":true}'    \
      --argjson encryptionConfiguration '{"encryptionType":"KMS"}'  \
      --argjson tags $(echo $tags_json | jq -rc)                    \
      '{repositoryName: $repositoryName, imageTagMutability: $imageTagMutability, tags: $tags, imageScanningConfiguration: $imageScanningConfiguration, encryptionConfiguration: $encryptionConfiguration}')

    # Create the repository
    ecr_create_repository_json=$(aws ecr create-repository --cli-input-json $ecr_create_repository_input)

    print_dbg "Created repository $name"

    # NOTE: Policy text is indented with three leading TABS on each line. Further
    # indendentation is done with spaces.
    repository_policy=$(cat <<-EOF
			{
			  "Version": "2012-10-17",
			  "Statement": [
			    {
			      "Sid": "OrganizationRead",
			      "Effect": "Allow",
			      "Principal": {
			        "AWS": "*"
			      },
			      "Action": [
			        "ecr:GetAuthorizationToken",
			        "ecr:GetDownloadUrlForLayer",
			        "ecr:BatchGetImage",
			        "ecr:BatchCheckLayerAvailability"
			      ],
			      "Condition": {
			        "StringLike": {
			          "aws:PrincipalOrgID": ["$org_id"]
			        }
			      }
			    }
			  ]
			}
			EOF
    )

    print_dbg "Setting policy for repository $name"

    # Set the repository policy
    ecr_set_repository_policy_json=$(aws ecr set-repository-policy \
      --repository-name "$name"   \
      --policy-text $(echo $repository_policy | jq -rcM)
    )

    print_dbg "Set policy for repository $name"
  fi
}

# Print script usage documentation
function usage() {
  echo "Usage: $(basename $0) -n NAME -o ORG_ID [-v]" 2>&1
  echo
  echo "Create and configure an ECR repository to share within an AWS Organization"
  echo
  echo "   -n NAME     The name of the repository"
  echo "   -o ORG_ID   Organization ID to allow read-access"
  echo "   -v          Enable verbose mode"
  exit 1
}

# Handle script arguments
verbose=0
org_id=
optstring=":n:o:v"
while getopts "$optstring" arg; do
  case ${arg} in
    n)
      name=$OPTARG
      ;;
    o)
      org_id=$OPTARG
      ;;
    v )
      verbose=1
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      echo
      usage
      ;;
    : )
      # Swallow error for the -o argument. If it doesn't exists, we'll query the
      # Organizations API for the value.
      if [ "$OPTARG" != "o" ]; then
        echo "Invalid option: -$OPTARG requires an argument" 1>&2
        echo
        usage
      fi
      ;;
  esac
done

shift $((OPTIND -1))

# Print a message about an argument being required and then print the script usage docs
function print_required() { printf "%s\n\n" "$1"; usage; }

# Check required argument(s)
[ ! -z "${name+set}"   ] || print_required "The name of the repository (-n) is required"

create_repository_if_not_exists
