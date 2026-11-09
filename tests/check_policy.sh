#!/usr/bin/env bash
# Keep support-policy.yaml honest: latest == Chart.yaml version, min <= latest, CHANGELOG entry exists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ver=$(yq '.version' "$ROOT/charts/golden-service/Chart.yaml")
min=$(yq '.minimumSupported' "$ROOT/support-policy.yaml")
latest=$(yq '.latest' "$ROOT/support-policy.yaml")
semver='^[0-9]+\.[0-9]+\.[0-9]+$'
for v in "$ver" "$min" "$latest"; do [[ "$v" =~ $semver ]] || { echo "not plain SemVer: $v"; exit 1; }; done
[ "$latest" = "$ver" ] || { echo "support-policy latest ($latest) != Chart.yaml version ($ver): update the policy when you release"; exit 1; }
[ "$(printf '%s\n%s\n' "$min" "$latest" | sort -V | head -1)" = "$min" ] || { echo "minimumSupported ($min) is newer than latest ($latest)"; exit 1; }
grep -q "^## \[$ver\]" "$ROOT/CHANGELOG.md" || { echo "CHANGELOG.md has no '## [$ver]' entry"; exit 1; }
echo "policy ok: min=$min latest=$latest (CHANGELOG has $ver)"
