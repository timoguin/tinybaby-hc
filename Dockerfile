FROM golang:1.13.5-alpine3.10 AS build

ARG GOOS="linux"
ARG GOARCH="amd64"
ARG CGO_ENABLED=0
ENV GOOS=${GOOS}
ENV GOARCH=${GOARCH}
ENV CGO_ENABLED=${CGO_ENABLED}

RUN apk --no-cache add git
ADD . /go/src/app
WORKDIR /go/src/app
RUN go get && go build -o tinybaby-hc

FROM scratch
COPY --from=build /go/src/app/tinybaby-hc /
CMD ["/tinybaby-hc"]
