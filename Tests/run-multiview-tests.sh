#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/f1-multiview-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
test_frameworks="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/Library/Frameworks"
test_libraries="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
    "$root"/F1A-TV/Models/*.swift \
    "$root"/F1A-TV/Util/Enum/{ChannelType,ContentObjectType,ContainerLayoutType,DriverChannelSortType}.swift \
    "$root"/F1A-TV/DataTransferObjects/Util/PlayerSettings.swift \
    "$root"/F1A-TV/Controller/Views/Player/LivePlaybackCoordinator.swift \
    "$root"/Tests/MultiviewFeatureTests.swift -o "$build_dir/MultiviewFeatureTests"
"$build_dir/MultiviewFeatureTests"
