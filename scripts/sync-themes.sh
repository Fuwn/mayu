#!/usr/bin/env bash

set -euo pipefail

upstream_repository="https://github.com/journey-ad/Moe-Counter"
upstream_revision="8abee4defc7c10b8d82103a36d826a24416e5169"
repository_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ge 1 ]]; then
  upstream="$1"
else
  upstream="$(mktemp -d)"

  trap 'rm -rf "${upstream}"' EXIT
  echo "Fetching ${upstream_repository} at ${upstream_revision} ..."
  git -C "${upstream}" init --quiet
  git -C "${upstream}" fetch --quiet --depth 1 "${upstream_repository}" "${upstream_revision}"
  git -C "${upstream}" checkout --quiet --detach FETCH_HEAD
fi

source_directory="${upstream}/assets/theme"

if [[ ! -d "${source_directory}" ]]; then
  echo "No theme directory at ${source_directory}" >&2
  exit 1
fi

rsync -a --ignore-existing "${source_directory}/" "${repository_root}/themes/"
echo "Synced themes into ${repository_root}/themes/"

theme_count="$(find "${repository_root}/themes" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

echo "Total themes: ${theme_count}"
