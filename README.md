# Tiny Baby Health Checker

A 9MB Golang web server that returns a 200 OK for the root path. The Docker
image is just as small since it's based off of the Docker scratch image.

To build:

    $ docker build -t tinybaby-hc:latest .

Available config options:

- `TINYBABY_LISTEN_ADDR`: Address for the server to listen on, defaults to `:5000`
