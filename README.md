# Tiny Baby Health Checker

An 8MB Golang web server that returns a 200 OK for the root path. The Docker
image is just as small since it's based off of the Docker scratch image.

To build:

    $ docker build -t tiny-baby .

Available config options:

- TINY_BABY_PORT: port for the server to listen on, defaults to 80
