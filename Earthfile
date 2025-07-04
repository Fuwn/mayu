VERSION 0.8

image-all-platforms:
  BUILD --platform=linux/amd64 --platform=linux/arm64 +image

image:
  ARG tag=latest

  FROM ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine

  COPY +build/erlang-shipment/ /mayu/erlang-shipment/
  COPY themes/ /mayu/themes/
  COPY index.html /mayu/
  COPY gleam.toml /mayu/

  ENV MAYU_VERSION=$(grep version /mayu/gleam.toml | cut -d '"' -f 2)

  RUN rm /mayu/gleam.toml

  WORKDIR /mayu/

  ENTRYPOINT ["./erlang-shipment/entrypoint.sh"]

  CMD ["run"]

  SAVE IMAGE --push fuwn/mayu:${tag}

build:
  FROM ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine

  RUN apk add --no-cache build-base

  WORKDIR /mayu/

  COPY src/ /mayu/src/
  COPY gleam.toml /mayu/
  COPY manifest.toml /mayu/

  RUN gleam build \
    && cd build/ \
    && gleam export erlang-shipment

  SAVE ARTIFACT /mayu/build/erlang-shipment/
