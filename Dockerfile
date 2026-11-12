# syntax=docker/dockerfile:1.7

FROM crystallang/crystal:1.22.2-alpine@sha256:a0c2fb92a6ce855e8d40bdffe729e2fcccf98dac929d0f9f589fad8c88e297a1 AS build

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# hadolint ignore=DL3018
RUN apk add --no-cache bash rsync sqlite-dev sqlite-static

WORKDIR /mayu

COPY shard.yml shard.lock ./

RUN shards install --production

COPY themes/ ./themes/
COPY scripts/ ./scripts/

RUN ./scripts/sync-themes.sh

COPY src/ ./src/

RUN shards build --production --release --static --no-debug -Dwithout_mt

FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

WORKDIR /mayu

COPY --from=build /mayu/bin/mayu ./
COPY index.html ./

RUN adduser -D -H mayu \
    && mkdir data \
    && chown mayu /mayu/data

USER mayu

ENTRYPOINT ["/mayu/mayu"]
