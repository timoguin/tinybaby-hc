FROM golang:1.13.5-alpine3.10 AS build

ARG GOOS="linux"
ARG GOARCH="amd64"
ARG CGO_ENABLED=0
ENV GOOS=${GOOS}
ENV GOARCH=${GOARCH}
ENV CGO_ENABLED=${CGO_ENABLED}

ADD . /go/src/app
WORKDIR /go/src/app
RUN apk --no-cache add git
RUN go get && go build -o tiny-baby-health-checker

FROM scratch
COPY --from=build /go/src/app/tiny-baby-health-checker /
EXPOSE 80
CMD ["/tiny-baby-health-checker"]
