VERSION 0.8

all:
  BUILD +docker

docker:
  ARG tag=latest

  FROM ghcr.io/gleam-lang/gleam:v1.2.0-erlang-alpine

  COPY +build/erlang-shipment/ /mayu/erlang-shipment/
  COPY themes/ /mayu/themes/
  COPY index.html /mayu/

  WORKDIR /mayu/

  ENTRYPOINT ["./erlang-shipment/entrypoint.sh"]

  CMD ["run"]

  SAVE IMAGE --push fuwn/mayu:${tag}

deps:
  FROM ghcr.io/gleam-lang/gleam:v1.2.0-erlang-alpine

  RUN apk add --no-cache build-base

build:
  FROM +deps

  WORKDIR /mayu/

  COPY src/ /mayu/src/
  COPY gleam.toml /mayu/
  COPY manifest.toml /mayu/

  RUN gleam build \
    && cd build/ \
    && gleam export erlang-shipment

  SAVE ARTIFACT /mayu/build/erlang-shipment/

