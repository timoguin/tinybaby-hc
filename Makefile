IMAGE_NAME    ?= tinybaby-hc
IMAGE_VERSION ?= 0.1.0

ORG_ID ?=

build :
	docker build -t ${IMAGE_NAME}:latest .

ecr :
	@printf "%s\n\n" "Ensuring ECR repository exists"
	./scripts/ensure_ecr_repository_exists.sh -v -n ${IMAGE_NAME} -o ${ORG_ID}
