# syntax=docker/dockerfile:1.7

FROM crystallang/crystal:1.22.2-alpine AS build

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

FROM alpine:3.24

WORKDIR /mayu

COPY --from=build /mayu/bin/mayu ./
COPY --from=build /mayu/themes/ ./themes/
COPY index.html ./

RUN adduser -D -H mayu \
    && mkdir data \
    && chown mayu /mayu/data

USER mayu

ENTRYPOINT ["/mayu/mayu"]
