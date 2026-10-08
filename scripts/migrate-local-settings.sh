#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATION_DIR="$(mktemp -d "${TMPDIR:-/tmp}/finderhelper-migration.XXXXXX")"
trap 'rm -rf "$MIGRATION_DIR"' EXIT
swiftc -swift-version 5 -parse-as-library \
    "$PROJECT_ROOT"/Sources/FinderHelperCore/*.swift \
    "$PROJECT_ROOT/scripts/migrate-local-settings.swift" \
    -o "$MIGRATION_DIR/migrate-settings"
"$MIGRATION_DIR/migrate-settings"
