import functools
import http.server
import sys
import time
import pathlib


class FixtureHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/preview-rejection/master.m3u8":
            data = b'#EXTM3U\n#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=120000,RESOLUTION=160x90,URI="/preview-rejection/frames.m3u8"\n#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=320x180\n/variant0.m3u8\n'
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.apple.mpegurl")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if self.path == "/preview-rejection/frames.m3u8":
            text = (pathlib.Path(self.directory) / "iframes/frames.m3u8").read_text()
            text = '\n'.join('/forbidden/' + line if line.endswith('.ts') else line for line in text.splitlines())
            data = (text + '\n').encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.apple.mpegurl")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if self.path == "/cdn-rejection/master.m3u8":
            data = b'#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=320x180\n/forbidden/variant.m3u8\n'
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.apple.mpegurl")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if self.path.startswith("/forbidden/"):
            self.send_error(403)
            return
        if self.path == "/iframes/frames.m3u8":
            time.sleep(0.35)  # Allow scrub targets to change during asset preparation.
        if self.path == "/redirect.m3u8":
            self.send_response(302)
            self.send_header("Location", "/master.m3u8")
            self.end_headers()
        else:
            super().do_GET()


server = http.server.ThreadingHTTPServer(
    ("127.0.0.1", 0), functools.partial(FixtureHandler, directory=sys.argv[1])
)
print(server.server_address[1], flush=True)
server.serve_forever()
