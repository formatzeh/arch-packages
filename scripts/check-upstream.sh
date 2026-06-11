#!/usr/bin/env bash
set -euo pipefail

for pkgdir in packages/*/; do
  pkgbuild="$pkgdir/PKGBUILD"
  [ -f "$pkgbuild" ] || continue

  source_url=$(grep -oP 'git\+https://github\.com/[^"]+' "$pkgbuild" | head -1) || continue
  [ -n "$source_url" ] || continue

  repo=$(echo "$source_url" | grep -oP 'github\.com/\K[^/]+/[^/.#]+')
  branch=$(echo "$source_url" | grep -oP '(?<=#branch=)\S+' | head -1)
  branch="${branch:-main}"

  upstream_file="${pkgdir}.upstream"

  latest=$(curl -sf \
    -H "Authorization: Bearer $GH_TOKEN" \
    "https://api.github.com/repos/$repo/commits/$branch" \
    | jq -r '.sha')

  stored=$(cat "$upstream_file" 2>/dev/null || echo "")

  if [ "$latest" = "$stored" ]; then
    echo "==> $(basename "$pkgdir"): up to date ($latest)"
  else
    echo "==> $(basename "$pkgdir"): new commit $latest (was ${stored:-none})"
    echo "$latest" > "$upstream_file"
  fi
done
