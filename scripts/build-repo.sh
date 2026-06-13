#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${REPO_NAME:-personal}"
ROOT_DIR="$(pwd)"
PKG_DIR="$ROOT_DIR/packages"
OUT_DIR="$ROOT_DIR/repo/x86_64"
BUILD_ALL=false

if [[ ${1:-} == "--all" ]]; then
  BUILD_ALL=true
  shift
fi

BUILD_TARGETS=("$@")

if [[ "$BUILD_ALL" == false && ${#BUILD_TARGETS[@]} -eq 0 ]]; then
  echo "No package build targets supplied. Use --all to build every package." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Building packages from: $PKG_DIR"
echo "Repo output: $OUT_DIR"

for package_dir in "$PKG_DIR"/*; do
  [ -d "$package_dir" ] || continue
  [ -f "$package_dir/PKGBUILD" ] || continue

  package_name="$(basename "$package_dir")"

  if [[ "$BUILD_ALL" == false ]] && \
     ! printf '%s\n' "${BUILD_TARGETS[@]}" | grep -qx "$package_name"; then
    echo "==> Skipping $package_name (unchanged)"
    continue
  fi

  echo "==> Building $package_name"

  cd "$package_dir"

  # Clean old local build artifacts, but keep the PKGBUILD.
  rm -rf pkg src *.pkg.tar.* *.log

  makepkg --noconfirm --syncdeps --cleanbuild --clean

  # Remove previous version of this package from the output dir before
  # copying the new one, so stale versions don't end up in the database.
  rm -f "$OUT_DIR"/"$package_name"-*.pkg.tar.zst
  cp ./*.pkg.tar.zst "$OUT_DIR/"

  cd "$ROOT_DIR"
done

cd "$OUT_DIR"

echo "==> Creating repository database"

rm -f "$REPO_NAME.db" "$REPO_NAME.files"

repo-add "$REPO_NAME.db.tar.gz" ./*.pkg.tar.zst

# repo-add creates symlinks like personal.db -> personal.db.tar.gz.
# GitHub Pages serves those fine.
ls -lah
