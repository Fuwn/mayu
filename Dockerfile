# syntax=docker/dockerfile:1.7

# The official Gleam images pair Gleam >= 1.14 only with OTP 28+, which
# crashes under Rosetta emulation during multi-arch builds, so the Gleam
# binary is installed onto an OTP 27 base instead.
FROM erlang:27-alpine AS build

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG TARGETARCH
ARG GLEAM_VERSION=v1.17.0

# hadolint ignore=DL3018
RUN apk add --no-cache build-base curl git rsync bash

RUN case "$TARGETARCH" in \
      amd64) triple=x86_64-unknown-linux-musl ;; \
      arm64) triple=aarch64-unknown-linux-musl ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2 && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam-${GLEAM_VERSION}-${triple}.tar.gz" \
    | tar -xzC /usr/local/bin gleam

WORKDIR /mayu

COPY gleam.toml manifest.toml ./
COPY src/ ./src/

RUN gleam build

COPY themes/ ./themes/
COPY scripts/ ./scripts/

RUN ./scripts/sync-themes.sh

WORKDIR /mayu/build

RUN gleam export erlang-shipment

FROM erlang:27-alpine

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

WORKDIR /mayu

COPY --from=build /mayu/build/erlang-shipment/ ./erlang-shipment/
COPY --from=build /mayu/themes/ ./themes/
COPY index.html ./
COPY gleam.toml ./

RUN grep '^version' gleam.toml | cut -d '"' -f 2 > .mayu-version \
    && rm gleam.toml

ENTRYPOINT ["sh", "-c", "exec env MAYU_VERSION=\"$(cat /mayu/.mayu-version)\" /mayu/erlang-shipment/entrypoint.sh \"$@\"", "--"]

CMD ["run"]
