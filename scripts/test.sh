#!/bin/bash
# Run core behavior checks using Command Line Tools, without XCTest/Xcode.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/finderhelper-checks.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -swift-version 5 -D FINDER_HELPER_STANDALONE_CHECKS \
    "$PROJECT_ROOT"/Sources/FinderHelperCore/*.swift \
    "$PROJECT_ROOT/Tests/FinderHelperCoreTests/StandaloneChecks.swift" \
    -o "$CHECK_DIR/finderhelper-core-checks"
"$CHECK_DIR/finderhelper-core-checks"
