FROM ghcr.io/gleam-lang/gleam:v1.1.0-erlang-alpine as builder

WORKDIR /mayu/

COPY src/ /mayu/src/
COPY themes/ /mayu/themes/
COPY gleam.toml /mayu/
COPY manifest.toml /mayu/

RUN apk add --no-cache build-base

RUN gleam build \
  && cd build/ \
  && gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.1.0-erlang-alpine

COPY --from=builder /mayu/build/erlang-shipment/ /mayu/erlang-shipment/
COPY --from=builder /mayu/themes /mayu/themes/

WORKDIR /mayu/

ENTRYPOINT ["./erlang-shipment/entrypoint.sh"]

CMD ["run"]
