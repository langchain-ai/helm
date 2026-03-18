"""Minimal JWKS server — serves /well-known/jwks.json from a mounted file."""

import http.server
import sys

JWKS_PATH = "/data/jwks.json"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/well-known/jwks.json":
            with open(JWKS_PATH, "r") as f:
                body = f.read().encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        print(f"[jwks-server] {fmt % args}", flush=True)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = http.server.HTTPServer(("0.0.0.0", port), Handler)
    print(f"[jwks-server] Listening on :{port}", flush=True)
    server.serve_forever()
