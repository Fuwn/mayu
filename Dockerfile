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

RUN gleam deps download

COPY themes/ ./themes/
COPY scripts/ ./scripts/

RUN ./scripts/sync-themes.sh

COPY src/ ./src/

RUN gleam export erlang-shipment

FROM erlang:27-alpine

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

WORKDIR /mayu

COPY --from=build /mayu/build/erlang-shipment/ ./erlang-shipment/
COPY --from=build /mayu/themes/ ./themes/
COPY index.html ./

RUN adduser -D -H mayu \
    && mkdir data \
    && chown mayu /mayu/data

USER mayu

# The default process table reserves room for about a million processes, and
# per-scheduler allocators add more fixed overhead; +P and +Mea min trim both.
# The BEAM also starts 15 normal, 15 dirty CPU, and 10 dirty I/O schedulers
# whatever the CPU limit, and idle schedulers busy-wait, which burns a small
# CPU quota and gets the container throttled. +S, +SDcpu, and +SDio start one
# of each, and the +sbwt flags stop the busy-waiting. These scheduler flags cap
# Mayu at one CPU, so raise them when giving the container more. On one CPU
# with every theme loaded, they cut idle memory from 45 MiB to 36 MiB, raised
# saved hits from about 4,800 to 7,500 per second, and cut p99 latency from
# about 49 ms to 18 ms.
ENV ERL_FLAGS="+P 262144 +Mea min +S 1:1 +SDcpu 1:1 +SDio 1 +sbwt none +sbwtdcpu none +sbwtdio none"

ENTRYPOINT ["/mayu/erlang-shipment/entrypoint.sh"]

CMD ["run"]
