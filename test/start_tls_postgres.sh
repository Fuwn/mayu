#!/usr/bin/env bash
# Start a disposable PostgreSQL container that serves TLS, with a certificate that names only
# localhost, for the certificate verification specs.
#
# Usage: test/start_tls_postgres.sh CERTIFICATE_DIRECTORY [PORT]

set -euo pipefail

certificate_directory=$1
port=${2:-5433}

mkdir -p "$certificate_directory"
cd "$certificate_directory"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=Mayu Test CA" \
  -keyout ca.key -out ca.crt 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj "/CN=localhost" \
  -keyout server.key -out server.csr 2>/dev/null
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 1 \
  -extfile <(printf 'subjectAltName = DNS:localhost\n') -out server.crt 2>/dev/null

docker run -d --name mayu-tls-postgres -p "127.0.0.1:$port:5432" \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=mayu_test \
  -v "$PWD/server.crt:/certificates/server.crt:ro" \
  -v "$PWD/server.key:/certificates/server.key:ro" \
  postgres:17-alpine sh -c '
    install -o postgres -m 600 /certificates/server.key /certificates/server.crt /var/lib/postgresql/
    exec docker-entrypoint.sh postgres -c ssl=on \
      -c ssl_cert_file=/var/lib/postgresql/server.crt \
      -c ssl_key_file=/var/lib/postgresql/server.key'

until docker exec mayu-tls-postgres pg_isready -U postgres -d mayu_test -h localhost >/dev/null; do
  sleep 1
done
