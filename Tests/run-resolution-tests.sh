#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/f1-resolution-tests.XXXXXX")"
server_pid=""
cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$build_dir"
}
trap cleanup EXIT
if [[ "${1:-}" == "--playback" ]]; then
    mkdir -p "$build_dir/hls/broken" "$build_dir/hls/live" "$build_dir/hls/fairplay"
    ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=320x180:rate=25 \
        -f lavfi -i sine=frequency=440:sample_rate=48000 \
        -filter_complex '[0:v]split=2[high][low];[low]scale=160:90[small]' \
        -map '[high]' -map 1:a -map '[small]' -map 1:a \
        -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 50 -keyint_min 50 -sc_threshold 0 \
        -b:v:0 300k -b:v:1 120k -c:a aac -b:a 64k -t 30 \
        -f hls -hls_time 2 -hls_playlist_type vod -hls_segment_filename "$build_dir/hls/%v_%03d.ts" \
        -master_pl_name master.m3u8 -var_stream_map 'v:0,a:0 v:1,a:1' "$build_dir/hls/variant%v.m3u8"
    sed -E 's/,RESOLUTION=[0-9]+x[0-9]+//g' "$build_dir/hls/master.m3u8" > "$build_dir/hls/no-resolution-master.m3u8"
    cp "$root/Tests/Fixtures/broken-master.m3u8" "$build_dir/hls/broken/master.m3u8"
    cp "$build_dir/hls/master.m3u8" "$build_dir/hls/live/master.m3u8"
    for variant in 0 1; do
        sed -e '/#EXT-X-ENDLIST/d' -e 's/#EXT-X-PLAYLIST-TYPE:VOD/#EXT-X-PLAYLIST-TYPE:EVENT/' -e 's|^\([01]_[0-9]*\.ts\)$|../\1|' \
            "$build_dir/hls/variant$variant.m3u8" > "$build_dir/hls/live/variant$variant.m3u8"
    done
    python3 - "$build_dir/hls" <<'PYFIXTURE'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
key = '#EXT-X-KEY:METHOD=SAMPLE-AES,URI="skd://0xfixture"'
# Synthetic key metadata exercises native key routing, not successful DRM decryption.
protected = (root / 'variant0.m3u8').read_text().replace('#EXT-X-VERSION:3', '#EXT-X-VERSION:5')
protected = protected.replace('#EXTINF:', key + '\n#EXTINF:', 1)
protected = '\n'.join('../' + line if line.endswith('.ts') else line for line in protected.splitlines())
(root / 'fairplay' / 'media.m3u8').write_text(protected + '\n')
master = (root / 'master.m3u8').read_text().replace('variant0.m3u8', 'media.m3u8').replace('variant1.m3u8', '../variant1.m3u8')
(root / 'fairplay' / 'master.m3u8').write_text(master)
tracks = root / 'tracks'
tracks.mkdir()
master = (root / 'master.m3u8').read_text()
master = master.replace('#EXT-X-STREAM-INF:', '#EXT-X-STREAM-INF:SUBTITLES="subs",')
master = master.replace('variant0.m3u8', '../variant0.m3u8').replace('variant1.m3u8', '../variant1.m3u8')
media = '\n'.join(f'#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="{name}",LANGUAGE="{code}",DEFAULT=NO,AUTOSELECT=YES,URI="{code}.m3u8"' for name, code in [('English', 'en'), ('Deutsch', 'de')])
(tracks / 'master.m3u8').write_text(master.replace('#EXTM3U', '#EXTM3U\n' + media))
for code in ['en', 'de']:
    (tracks / f'{code}.m3u8').write_text(f'#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:30\n#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXTINF:30,\n{code}.vtt\n#EXT-X-ENDLIST\n')
    (tracks / f'{code}.vtt').write_text(f'WEBVTT\n\n00:00.000 --> 00:30.000\n{code} fixture captions\n')
PYFIXTURE
    python3 "$root/Tests/serve-playback-fixtures.py" "$build_dir/hls" > "$build_dir/port" 2> "$build_dir/server.log" &
    server_pid=$!
    for ((attempt=0; attempt<100; attempt++)); do
        if [[ -s "$build_dir/port" ]]; then break; fi
        sleep 0.05
    done
    export F1_RESOLUTION_FIXTURE_URL="http://127.0.0.1:$(head -n 1 "$build_dir/port")"
fi
test_frameworks="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/Library/Frameworks"
test_libraries="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$build_dir/cache" \
    -F "$test_frameworks" -Xlinker -rpath -Xlinker "$test_frameworks" \
    -I "$test_libraries" -L "$test_libraries" -Xlinker -rpath -Xlinker "$test_libraries" \
    "$root"/F1A-TV/Util/M3U8Parser/Models/Tags/*.swift \
    "$root"/F1A-TV/Util/M3U8Parser/Models/Playlist/*.swift \
    "$root"/F1A-TV/Util/M3U8Parser/Parser/HLSResolutionPlaylist.swift \
    "$root"/F1A-TV/Util/M3U8Parser/Parser/HLSPreviewPlaylist.swift \
    "$root"/F1A-TV/DataTransferObjects/Util/FairPlayer.swift \
    "$root"/F1A-TV/Extensions/AVPlayerItemExtension.swift \
    "$root"/F1A-TV/DataTransferObjects/Util/PlaybackDefaults.swift \
    "$root"/F1A-TV/DataTransferObjects/Util/PlayerSettings.swift \
    "$root"/F1A-TV/Models/DefaultFeed.swift \
    "$root"/F1A-TV/Util/Enum/ChannelType.swift \
    "$root"/F1A-TV/Util/Enum/DriverChannelSortType.swift \
    "$root"/F1A-TV/DataTransferObjects/Util/AppErrorStore.swift \
    "$root"/F1A-TV/Networking/FairPlayLicenseRequest.swift \
    "$root"/F1A-TV/Models/PlaybackEntitlement.swift \
    "$root"/F1A-TV/Networking/Services/FairPlayKeyLoader.swift \
    "$root"/F1A-TV/Networking/Services/AVFoundationFairPlayAdapter.swift \
    "$root"/F1A-TV/Networking/Services/HTTPTransport.swift \
    "$root"/F1A-TV/Networking/CatalogRequest.swift \
    "$root"/Tests/PlaybackTestSupport.swift \
    "$root"/Tests/FairPlayerResolutionTests.swift \
    "$root"/Tests/PreviewPlaylistTests.swift \
    "$root"/Tests/ResolutionSelectionTests.swift -o "$build_dir/ResolutionSelectionTests"
"$build_dir/ResolutionSelectionTests"
