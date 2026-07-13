#!/usr/bin/env bash
#
# verify.sh — build gate for the marketplace backend component.
#
# The required gate for this target is `docker build` (per the harness). If a
# local Go toolchain is present we also run vet + tests for faster feedback,
# but the Docker build is the source of truth. Exits non-zero on any failure.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> [1/2] Go vet + tests (skipped if 'go' is not installed)"
if command -v go >/dev/null 2>&1; then
  go vet ./...
  go test ./...
else
  echo "    go not found on PATH — relying on the Docker build below."
fi

echo "==> [2/2] docker build"
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required to verify this component but was not found." >&2
  exit 1
fi
docker build -t marketplace-backend:verify .

echo "==> OK: backend verified."
