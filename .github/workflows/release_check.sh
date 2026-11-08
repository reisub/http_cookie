#!/bin/bash
set -Eeuo pipefail

# Decides what the publish workflow has to do for the current commit and
# writes it to $GITHUB_OUTPUT. Runs no Elixir and needs no credentials.

# Assume package name == repository name
package="${GITHUB_REPOSITORY#*/}"
version=$(.github/workflows/version.sh)

# Assigned first so a failing git command stops the script
tags=$(git ls-remote --tags origin "refs/tags/v$version")

if [[ -n $tags ]]; then
  tag=false
else
  tag=true
fi

status=$(curl --silent --show-error --proto '=https' --retry 3 --output /dev/null \
  --write-out '%{http_code}' "https://hex.pm/api/packages/$package/releases/$version")

case "$status" in
200) publish=false ;;
404) publish=true ;;
*)
  echo "Unexpected response from hex.pm: HTTP $status" >&2
  exit 1
  ;;
esac

echo "version=$version tag=$tag publish=$publish"

{
  echo "version=$version"
  echo "tag=$tag"
  echo "publish=$publish"
} >>"$GITHUB_OUTPUT"
