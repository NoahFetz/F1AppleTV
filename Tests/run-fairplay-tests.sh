#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/f1-fairplay-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
test_frameworks="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/Library/Frameworks"
test_libraries="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
    "$root/F1A-TV/Models/PlaybackEntitlement.swift" \
    "$root/F1A-TV/Networking/FairPlayLicenseRequest.swift" \
    "$root/Tests/FairPlayLicenseRequestTests.swift" -o "$build_dir/FairPlayLicenseRequestTests"
"$build_dir/FairPlayLicenseRequestTests"
