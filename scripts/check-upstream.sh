#!/usr/bin/env bash
set -euo pipefail

changed_packages=()
auth_args=()

if [ -n "${GH_TOKEN:-}" ]; then
  auth_args=(-H "Authorization: Bearer $GH_TOKEN")
fi

for pkgdir in packages/*/; do
  pkgbuild="$pkgdir/PKGBUILD"
  [ -f "$pkgbuild" ] || continue

  source_url=$(grep -oE 'git\+https://github\.com/[^"]+' "$pkgbuild" | head -1) || continue
  [ -n "$source_url" ] || continue

  repo="${source_url#*github.com/}"
  repo="${repo%%#*}"
  repo="${repo%.git}"

  branch=$(sed -n 's/^_upstream_branch=//p' "$pkgbuild" | head -1)
  branch="${branch//\"/}"
  branch="${branch//\'/}"
  branch="${branch:-main}"

  stored=$(sed -n 's/^_commit=//p' "$pkgbuild" | head -1)
  stored="${stored//\"/}"
  stored="${stored//\'/}"

  if [ -z "$stored" ]; then
    echo "==> $(basename "$pkgdir"): skipping (no _commit variable)"
    continue
  fi

  latest=$(curl -fsSL "${auth_args[@]}" \
    "https://api.github.com/repos/$repo/commits/$branch" \
    | jq -er '.sha')

  if [ "$latest" = "$stored" ]; then
    echo "==> $(basename "$pkgdir"): up to date ($latest)"
  else
    echo "==> $(basename "$pkgdir"): new commit $latest (was ${stored:-none})"
    sed -i "s/^_commit=.*/_commit=$latest/" "$pkgbuild"
    changed_packages+=("$(basename "$pkgdir")")
  fi
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'packages=%s\n' "${changed_packages[*]}" >> "$GITHUB_OUTPUT"
fi
