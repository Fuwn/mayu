# syntax=docker/dockerfile:1.7

FROM ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine AS build

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# hadolint ignore=DL3018
RUN apk add --no-cache build-base

WORKDIR /mayu

COPY gleam.toml manifest.toml ./
COPY src/ ./src/

RUN gleam build

WORKDIR /mayu/build

RUN gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

WORKDIR /mayu

COPY --from=build /mayu/build/erlang-shipment/ ./erlang-shipment/
COPY themes/ ./themes/
COPY index.html ./
COPY gleam.toml ./

RUN grep '^version' gleam.toml | cut -d '"' -f 2 > .mayu-version \
    && rm gleam.toml

ENTRYPOINT ["sh", "-c", "exec env MAYU_VERSION=\"$(cat /mayu/.mayu-version)\" /mayu/erlang-shipment/entrypoint.sh \"$@\"", "--"]

CMD ["run"]
