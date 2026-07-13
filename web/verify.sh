#!/usr/bin/env bash
#
# verify.sh — build gate for the marketplace web component.
#
# The required gate for this target is `docker build` (per the harness). If a
# local Node toolchain is present we also run the type-check + Vite build for
# faster feedback, but the Docker build is the source of truth. Exits non-zero
# on any failure.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> [1/2] Node type-check + build (skipped if 'npm' is not installed)"
if command -v npm >/dev/null 2>&1; then
  if [ ! -d node_modules ]; then
    echo "    installing dependencies (npm ci)…"
    npm ci
  fi
  npm run build
else
  echo "    npm not found on PATH — relying on the Docker build below."
fi

echo "==> [2/2] docker build"
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required to verify this component but was not found." >&2
  exit 1
fi
docker build -t marketplace-web:verify .

echo "==> OK: web verified."
