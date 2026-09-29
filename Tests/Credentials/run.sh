#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
# Compile the production helpers with deterministic storage doubles instead of
# Security.framework. The application build separately checks the real APIs.
sed '/^import Security$/d' F1A-TV/Util/KeychainHelper.swift > "$test_dir/KeychainHelper.swift"
xcrun swiftc -swift-version 5 \
  Tests/Credentials/StorageDoubles.swift \
  "$test_dir/KeychainHelper.swift" \
  F1A-TV/Util/CredentialHelper.swift \
  Tests/Credentials/main.swift \
  -o "$test_dir/credential-tests"
"$test_dir/credential-tests"
