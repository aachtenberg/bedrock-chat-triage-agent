import base64
import hashlib
import hmac as hmac_lib
import json
import os
import secrets
import urllib.parse
import urllib.request

CLIENT_ID         = os.environ["COGNITO_CLIENT_ID"]
CLIENT_SECRET     = os.environ["COGNITO_CLIENT_SECRET"]
COGNITO_DOMAIN    = os.environ["COGNITO_DOMAIN"]
SESSION_SECRET    = os.environ["SESSION_SECRET"]
SESSION_TTL       = int(os.environ.get("SESSION_TTL_SECONDS", "3600"))
IDENTITY_PROVIDER = os.environ.get("COGNITO_IDENTITY_PROVIDER", "Microsoft")

AUTH_ENDPOINT  = f"https://{COGNITO_DOMAIN}/oauth2/authorize"
TOKEN_ENDPOINT = f"https://{COGNITO_DOMAIN}/oauth2/token"


def make_session_token(nonce: str) -> str:
    """Return nonce.HMAC-SHA256(secret, nonce) — same format the CloudFront Function validates."""
    sig = hmac_lib.new(SESSION_SECRET.encode(), nonce.encode(), hashlib.sha256).hexdigest()
    return f"{nonce}.{sig}"


def cookie_header(name: str, value: str, max_age: int, path: str = "/") -> str:
    return f"{name}={value}; Path={path}; HttpOnly; Secure; SameSite=Lax; Max-Age={max_age}"


def redirect(location: str, cookies: list | None = None) -> dict:
    resp: dict = {
        "statusCode": 302,
        "headers": {"Location": location, "Cache-Control": "no-store"},
        "body": "",
    }
    if cookies:
        resp["cookies"] = cookies
    return resp


def error(status: int, message: str) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "text/plain; charset=utf-8"},
        "body": message,
    }


def handle_login(event: dict) -> dict:
    params = event.get("queryStringParameters") or {}
    redirect_path = params.get("redirect", "/")
    if not redirect_path.startswith("/"):
        redirect_path = "/"

    # origin is passed by login.html as window.location.origin so the callback
    # Lambda can derive the absolute redirect_uri without referencing the CF domain
    # in Terraform (which would create a circular dependency).
    origin = params.get("origin", "")
    if not origin.startswith("https://"):
        return error(400, "Missing or invalid origin parameter.")

    redirect_uri = origin + "/api/callback"

    # Encode redirect_path and redirect_uri in state so the callback can use them.
    state_payload = json.dumps({"r": redirect_path, "ru": redirect_uri, "o": origin})
    state = base64.urlsafe_b64encode(state_payload.encode()).decode().rstrip("=")

    auth_params = urllib.parse.urlencode({
        "client_id":         CLIENT_ID,
        "response_type":     "code",
        "scope":             "openid email profile",
        "redirect_uri":      redirect_uri,
        "identity_provider": IDENTITY_PROVIDER,
        "state":             state,
    })

    return redirect(f"{AUTH_ENDPOINT}?{auth_params}")


def handle_callback(event: dict) -> dict:
    params = event.get("queryStringParameters") or {}
    code      = params.get("code")
    state_b64 = params.get("state", "")

    if not code:
        return error(400, "Missing authorization code.")

    # Decode state.
    try:
        padding    = "=" * (4 - len(state_b64) % 4)
        state_data = json.loads(base64.urlsafe_b64decode(state_b64 + padding))
        redirect_path = state_data.get("r", "/")
        redirect_uri  = state_data.get("ru", "")
        origin        = state_data.get("o", "")
    except Exception:
        return error(400, "Invalid state parameter.")

    if not redirect_uri or not origin:
        return error(400, "State missing redirect_uri or origin.")

    # Exchange authorization code for tokens.
    token_body = urllib.parse.urlencode({
        "grant_type":   "authorization_code",
        "client_id":    CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "code":         code,
        "redirect_uri": redirect_uri,
    }).encode()

    req = urllib.request.Request(
        TOKEN_ENDPOINT,
        data=token_body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            tokens = json.loads(resp.read())
    except Exception as exc:
        return error(502, f"Token exchange failed: {exc}")

    if "error" in tokens:
        return error(502, f"Cognito error: {tokens.get('error_description', tokens['error'])}")

    id_token = tokens.get("id_token")
    if not id_token:
        return error(502, "No id_token in token response.")

    # Parse claims (trusted — received directly from token endpoint over TLS).
    try:
        segment  = id_token.split(".")[1]
        segment += "=" * (4 - len(segment) % 4)
        claims   = json.loads(base64.b64decode(segment))
        sub      = claims.get("sub", "unknown")
    except Exception:
        sub = "unknown"

    # Create an HMAC-signed session token (nonce.hmac).
    nonce         = secrets.token_hex(16)
    session_token = make_session_token(nonce)

    auth_cookie   = cookie_header("_auth", session_token, SESSION_TTL)
    clear_state   = cookie_header("_state", "", 0, "/api")

    if not redirect_path.startswith("/"):
        redirect_path = "/"

    return redirect(origin + redirect_path, [auth_cookie, clear_state])


def handler(event: dict, context: object) -> dict:
    path = event.get("rawPath", "")
    if path.endswith("/login"):
        return handle_login(event)
    if path.endswith("/callback"):
        return handle_callback(event)
    return error(404, "Not found.")
