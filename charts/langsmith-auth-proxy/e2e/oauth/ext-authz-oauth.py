"""ext_authz service that performs an OAuth2 client-credentials token exchange.

Runs as a sidecar (or standalone service) alongside the main auth-proxy component.
On each ext_authz check request it returns a cached OAuth access token,
refreshing it from the configured token endpoint when expired.

Environment variables:
  OAUTH_TOKEN_URL    – Token endpoint (e.g. https://login.example.com/oauth/token)
  OAUTH_CLIENT_ID    – Client ID for the credentials grant
  OAUTH_CLIENT_SECRET– Client secret for the credentials grant
  OAUTH_SCOPE        – (optional) Space-separated scopes to request
  LISTEN_PORT        – (optional) Port to listen on, default 10002
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import sys
import threading
import time
import urllib.request
import urllib.parse

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
TOKEN_URL = os.environ["OAUTH_TOKEN_URL"]
CLIENT_ID = os.environ["OAUTH_CLIENT_ID"]
CLIENT_SECRET = os.environ["OAUTH_CLIENT_SECRET"]
SCOPE = os.environ.get("OAUTH_SCOPE", "")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "10002"))

# Refresh the token this many seconds before it actually expires.
EXPIRY_BUFFER_SECONDS = 30

# ---------------------------------------------------------------------------
# Token cache (thread-safe)
# ---------------------------------------------------------------------------
_lock = threading.Lock()
_cached_token: str | None = None
_token_expiry: float = 0  # epoch seconds


def _fetch_token() -> tuple[str, float]:
    """Perform a client_credentials grant and return (access_token, expiry_epoch)."""
    data = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        **({"scope": SCOPE} if SCOPE else {}),
    }).encode()

    req = urllib.request.Request(
        TOKEN_URL,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = json.loads(resp.read())

    access_token = body["access_token"]
    expires_in = int(body.get("expires_in", 3600))
    expiry = time.time() + expires_in - EXPIRY_BUFFER_SECONDS
    return access_token, expiry


def get_token() -> str:
    """Return a valid access token, refreshing if necessary."""
    global _cached_token, _token_expiry
    with _lock:
        if _cached_token and time.time() < _token_expiry:
            return _cached_token
    # Fetch outside the lock so other requests aren't blocked on I/O.
    token, expiry = _fetch_token()
    with _lock:
        _cached_token = token
        _token_expiry = expiry
    print(f"Refreshed OAuth token (expires in {int(expiry - time.time())}s)", flush=True)
    return token


# ---------------------------------------------------------------------------
# ext_authz HTTP handler
# ---------------------------------------------------------------------------
class Handler(BaseHTTPRequestHandler):
    def do_any(self):
        try:
            token = get_token()
        except Exception as exc:
            print(f"OAuth token fetch failed: {exc}", flush=True)
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OAuth token exchange failed")
            return

        self.send_response(200)
        # Replace the header name as needed - this header will be forwarded to the upstream LLM provider / gateway.
        self.send_header("Authorization", f"Bearer {token}")
        self.end_headers()

    # Handle every method Envoy might send for ext_authz checks.
    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = do_any

    def log_message(self, format, *args):
        # Quieter logs — only print errors.
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", LISTEN_PORT), Handler)
    print(f"ext-authz-oauth listening on :{LISTEN_PORT}", flush=True)
    print(f"  token_url={TOKEN_URL} client_id=<redacted>", flush=True)
    server.serve_forever()
