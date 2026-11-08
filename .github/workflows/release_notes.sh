#!/bin/bash
set -Eeuo pipefail

# Prints the CHANGELOG.md entry for a version (default: the one in mix.exs),
# without its heading, for the GitHub release notes.

cd "$(dirname "$0")/../.."
version=${1:-$(.github/workflows/version.sh)}

# Everything between "## [$version]" and the next "## [" heading, skipping
# leading blank lines. $(...) drops the trailing ones.
notes=$(awk -v heading="## [$version]" '
  found && /^## \[/ { exit }
  index($0, heading) == 1 { found = 1; next }
  found && !started && NF == 0 { next }
  found { started = 1; print }
' CHANGELOG.md)

if [[ -z $notes ]]; then
  echo "CHANGELOG.md has no entry for $version" >&2
  exit 1
fi

echo "$notes"
