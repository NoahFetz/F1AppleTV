#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/f1-catalog-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
test_frameworks="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/Library/Frameworks"
test_libraries="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
    "$root"/F1A-TV/Models/*.swift \
    "$root/F1A-TV/Networking/Wire/CatalogDTO.swift" "$root/F1A-TV/Networking/Services/HTTPTransport.swift" \
    "$root/F1A-TV/Networking/Services/CatalogService.swift" "$root/F1A-TV/Util/Enum/ChannelType.swift" \
    "$root/F1A-TV/Util/Enum/APIStreamType.swift" "$root/Tests/CatalogTestSupport.swift" \
    "$root/F1A-TV/Util/Enum/ContainerLayoutType.swift" "$root/F1A-TV/Util/Enum/ContentObjectType.swift" \
    "$root/F1A-TV/Networking/CatalogRequest.swift" \
    "$root/F1A-TV/Networking/CatalogArtworkRequest.swift" \
    "$root/F1A-TV/DataTransferObjects/Util/CatalogNavigation.swift" \
    "$root/F1A-TV/DataTransferObjects/Util/PlayerSettings.swift" "$root/F1A-TV/Util/Enum/DriverChannelSortType.swift" \
    "$root/F1A-TV/Controller/Views/Player/StreamPreviewCoordinator.swift" \
    "$root/F1A-TV/DataTransferObjects/Util/AppErrorStore.swift" "$root/F1A-TV/DataTransferObjects/Util/CatalogPresentation.swift" \
    "$root/Tests/CatalogPageTests.swift" -o "$build_dir/CatalogPageTests"
F1_CATALOG_FIXTURES="$root/Tests/Fixtures/Catalog" "$build_dir/CatalogPageTests"
