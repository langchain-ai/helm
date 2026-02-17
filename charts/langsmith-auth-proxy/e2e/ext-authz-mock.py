"""Minimal ext_authz HTTP mock for e2e testing.

Listens on :10002, logs received headers, and returns 200 with an
Authorization header that Envoy will forward upstream.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import sys


class Handler(BaseHTTPRequestHandler):
    def do_any(self):
        print(f"ext_authz check: {self.command} {self.path}", flush=True)
        for k, v in self.headers.items():
            print(f"  {k}: {v}", flush=True)
        self.send_response(200)
        self.send_header("Authorization", "Bearer fake-upstream-key")
        self.end_headers()

    # Handle every HTTP method the same way
    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = do_any


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 10002), Handler)
    print("ext_authz mock listening on :10002", flush=True)
    server.serve_forever()
