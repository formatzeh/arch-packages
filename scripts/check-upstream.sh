#!/usr/bin/env bash
set -euo pipefail

changed_packages=()

get_latest_commit() {
  local repo="$1"
  local branch="$2"
  local attempt=1
  local max_attempts=5
  local delay=5
  local latest=""

  while true; do
    latest="$(
      git ls-remote --exit-code "https://github.com/${repo}.git" "refs/heads/${branch}" 2>/dev/null \
        | awk '{print $1}'
    )" && {
      if [ -n "$latest" ]; then
        printf '%s\n' "$latest"
        return 0
      fi
    }

    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "ERROR: Could not fetch latest commit for ${repo}@${branch} after ${attempt} attempts" >&2
      return 1
    fi

    echo "WARN: Could not fetch ${repo}@${branch}; retrying in ${delay}s (${attempt}/${max_attempts})" >&2
    sleep "$delay"

    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

for pkgdir in packages/*/; do
  pkgbuild="${pkgdir}/PKGBUILD"
  [ -f "$pkgbuild" ] || continue

  pkgname="$(basename "$pkgdir")"

  source_url="$(
    grep -oE 'git\+https://github\.com/[^"'\'' ]+' "$pkgbuild" | head -1 || true
  )"

  if [ -z "$source_url" ]; then
    echo "==> ${pkgname}: skipping (no GitHub git source)"
    continue
  fi

  repo="${source_url#*github.com/}"
  repo="${repo%%#*}"
  repo="${repo%.git}"

  branch="$(sed -n 's/^_upstream_branch=//p' "$pkgbuild" | head -1)"
  branch="${branch//\"/}"
  branch="${branch//\'/}"
  branch="${branch:-main}"

  stored="$(sed -n 's/^_commit=//p' "$pkgbuild" | head -1)"
  stored="${stored//\"/}"
  stored="${stored//\'/}"

  if [ -z "$stored" ]; then
    echo "==> ${pkgname}: skipping (no _commit variable)"
    continue
  fi

  echo "==> ${pkgname}: checking ${repo}@${branch}"

  latest="$(get_latest_commit "$repo" "$branch")"

  if [ "$latest" = "$stored" ]; then
    echo "==> ${pkgname}: up to date (${latest})"
  else
    echo "==> ${pkgname}: new commit ${latest} (was ${stored})"
    sed -i "s/^_commit=.*/_commit=${latest}/" "$pkgbuild"
    changed_packages+=("$pkgname")
  fi
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'packages=%s\n' "${changed_packages[*]}" >> "$GITHUB_OUTPUT"
fi
