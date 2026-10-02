import functools
import http.server
import sys


class FixtureHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
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
