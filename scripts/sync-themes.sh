#!/usr/bin/env bash

set -euo pipefail

upstream_repository="https://github.com/journey-ad/Moe-Counter"
repository_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ge 1 ]]; then
  upstream="$1"
else
  upstream="$(mktemp -d)"

  trap 'rm -rf "${upstream}"' EXIT
  echo "Cloning ${upstream_repository} ..."
  git clone --quiet --depth 1 "${upstream_repository}" "${upstream}"
fi

source_directory="${upstream}/assets/theme"

if [[ ! -d "${source_directory}" ]]; then
  echo "No theme directory at ${source_directory}" >&2
  exit 1
fi

rsync -a --ignore-existing "${source_directory}/" "${repository_root}/themes/"
echo "Synced themes into ${repository_root}/themes/"

theme_count="$(($(find "${repository_root}/themes" -mindepth 1 -maxdepth 1 -type d | wc -l)))"

echo "Total themes: ${theme_count}"
