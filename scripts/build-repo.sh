#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${REPO_NAME:-personal}"
ROOT_DIR="$(pwd)"
PKG_DIR="$ROOT_DIR/packages"
OUT_DIR="$ROOT_DIR/repo/x86_64"

mkdir -p "$OUT_DIR"

rm -f "$OUT_DIR"/*.pkg.tar.*
rm -f "$OUT_DIR"/*.db*
rm -f "$OUT_DIR"/*.files*

echo "Building packages from: $PKG_DIR"
echo "Repo output: $OUT_DIR"

for package_dir in "$PKG_DIR"/*; do
  [ -d "$package_dir" ] || continue
  [ -f "$package_dir/PKGBUILD" ] || continue

  package_name="$(basename "$package_dir")"
  echo "==> Building $package_name"

  cd "$package_dir"

  # Clean old local build artifacts, but keep the PKGBUILD.
  rm -rf pkg src *.pkg.tar.* *.log

  makepkg --noconfirm --syncdeps --cleanbuild --clean

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
