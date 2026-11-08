#!/bin/bash
set -Eeuo pipefail

# Prints the package version from mix.exs without running Elixir, so
# workflows that hold credentials don't need to compile anything.
# The lint job in ci.yml checks that both stay in sync.

cd "$(dirname "$0")/../.."

version=$(sed -n 's/^  @version "\(.*\)"$/\1/p' mix.exs)

if [[ -z $version ]]; then
  echo "version extraction failed" >&2
  exit 1
fi

echo "$version"
