#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/f1-backend-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
test_frameworks="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/Library/Frameworks"
test_libraries="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
    "$root"/F1A-TV/Models/*.swift "$root"/F1A-TV/Networking/Wire/*.swift \
    "$root"/F1A-TV/Networking/Services/{HTTPTransport,AuthService,CatalogService,PlaybackService,FairPlayService,FairPlayKeyLoader,AVFoundationFairPlayAdapter}.swift \
    "$root"/F1A-TV/Networking/{CatalogRequest,FairPlayLicenseRequest}.swift \
    "$root"/F1A-TV/DataTransferObjects/Security/DeviceRegistration/*.swift \
    "$root"/F1A-TV/DataTransferObjects/Security/AuthDataDto.swift \
    "$root"/F1A-TV/DataTransferObjects/Util/{CatalogNavigation,AppErrorStore}.swift \
    "$root"/F1A-TV/Util/Enum/{ChannelType,ContentObjectType,ContainerLayoutType}.swift \
    "$root"/Tests/BackendServiceTests.swift -o "$build_dir/BackendServiceTests"
F1_BACKEND_FIXTURES="$root/Tests/Fixtures/Backend" "$build_dir/BackendServiceTests"
