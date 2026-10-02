#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# Use an already-resolved Alamofire checkout; this test does not update dependencies or access the network.
alamofire="${F1_ALAMOFIRE_SOURCE:?Set F1_ALAMOFIRE_SOURCE to the resolved Alamofire checkout}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/f1-transport-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(rg --files "$alamofire/Source" -g '*.swift')
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -emit-module -emit-library -module-name Alamofire "${sources[@]}" \
    -emit-module-path "$build_dir/Alamofire.swiftmodule" -o "$build_dir/libAlamofire.dylib"
test_frameworks="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/Library/Frameworks"
test_libraries="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
    -I "$build_dir" -L "$build_dir" -lAlamofire -Xlinker -rpath -Xlinker "$build_dir" \
    "$root"/F1A-TV/Networking/Services/{HTTPTransport,AlamofireHTTPTransport}.swift \
    "$root"/F1A-TV/Networking/CatalogRequest.swift "$root"/F1A-TV/DataTransferObjects/Util/AppErrorStore.swift \
    "$root"/Tests/AlamofireTransportTests.swift -o "$build_dir/AlamofireTransportTests"
"$build_dir/AlamofireTransportTests"
