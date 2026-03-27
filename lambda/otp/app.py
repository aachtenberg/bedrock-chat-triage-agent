import hashlib
import hmac as hmac_lib
import json
import os
import random
import secrets
import time

import boto3

TABLE_NAME      = os.environ["OTP_TABLE_NAME"]
SENDER_EMAIL    = os.environ["OTP_SENDER_EMAIL"]
SESSION_SECRET  = os.environ["SESSION_SECRET"]
SESSION_TTL     = int(os.environ.get("SESSION_TTL_SECONDS", "3600"))
OTP_TTL         = int(os.environ.get("OTP_TTL_SECONDS", "600"))

# Comma-separated list of allowed email domains. Empty = no restriction.
_raw = os.environ.get("OTP_ALLOWED_DOMAINS", "")
ALLOWED_DOMAINS = [d.strip().lower() for d in _raw.split(",") if d.strip()]

dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(TABLE_NAME)
ses      = boto3.client("ses")


def make_session_token(nonce: str) -> str:
    sig = hmac_lib.new(SESSION_SECRET.encode(), nonce.encode(), hashlib.sha256).hexdigest()
    return f"{nonce}.{sig}"


def cookie_header(name: str, value: str, max_age: int, path: str = "/") -> str:
    return f"{name}={value}; Path={path}; HttpOnly; Secure; SameSite=Lax; Max-Age={max_age}"


def json_resp(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def allowed_email(email: str) -> bool:
    if not ALLOWED_DOMAINS:
        return True
    domain = email.lower().split("@")[-1]
    return domain in ALLOWED_DOMAINS


def handle_request(event: dict) -> dict:
    try:
        body  = json.loads(event.get("body") or "{}")
        email = (body.get("email") or "").strip().lower()
    except Exception:
        return json_resp(400, {"error": "Invalid request body."})

    if not email or "@" not in email or "." not in email.split("@")[-1]:
        return json_resp(400, {"error": "Invalid email address."})

    if not allowed_email(email):
        return json_resp(403, {"error": "Email domain not permitted."})

    now = int(time.time())

    # Rate-limit: one code request per 60 seconds per email.
    existing = table.get_item(Key={"email": email}).get("Item")
    if existing and existing.get("last_requested_at", 0) > now - 60:
        return json_resp(429, {"error": "Please wait before requesting another code."})

    code = f"{random.SystemRandom().randint(0, 999_999):06d}"

    table.put_item(Item={
        "email":             email,
        "code":              code,
        "expires_at":        now + OTP_TTL,
        "last_requested_at": now,
        "attempts":          0,
    })

    try:
        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [email]},
            Message={
                "Subject": {"Data": "Your Bedrock Chat login code"},
                "Body": {
                    "Text": {
                        "Data": (
                            f"Your one-time login code is:\n\n"
                            f"  {code}\n\n"
                            f"It expires in {OTP_TTL // 60} minutes. "
                            f"Do not share this code with anyone."
                        )
                    }
                },
            },
        )
    except Exception as exc:
        return json_resp(502, {"error": f"Failed to send email: {exc}"})

    return json_resp(200, {"message": "Code sent — check your email."})


def handle_verify(event: dict) -> dict:
    try:
        body  = json.loads(event.get("body") or "{}")
        email = (body.get("email") or "").strip().lower()
        code  = (body.get("code") or "").strip()
    except Exception:
        return json_resp(400, {"error": "Invalid request body."})

    if not email or not code:
        return json_resp(400, {"error": "Email and code are required."})

    now  = int(time.time())
    item = table.get_item(Key={"email": email}).get("Item")

    if not item or item.get("expires_at", 0) < now:
        return json_resp(400, {"error": "Code expired or not found. Request a new one."})

    attempts = int(item.get("attempts", 0))
    if attempts >= 5:
        table.delete_item(Key={"email": email})
        return json_resp(429, {"error": "Too many attempts. Request a new code."})

    # Constant-time comparison to prevent timing attacks.
    if not hmac_lib.compare_digest(item["code"], code):
        table.update_item(
            Key={"email": email},
            UpdateExpression="SET attempts = :a",
            ExpressionAttributeValues={":a": attempts + 1},
        )
        remaining = 4 - attempts
        return json_resp(400, {"error": f"Incorrect code. {remaining} attempt(s) remaining."})

    # Valid — delete the OTP record and issue a session cookie.
    table.delete_item(Key={"email": email})

    params        = event.get("queryStringParameters") or {}
    redirect_path = params.get("redirect", "/")
    if not redirect_path.startswith("/"):
        redirect_path = "/"
    origin = params.get("origin", "")
    if not origin.startswith("https://"):
        origin = ""

    nonce         = secrets.token_hex(16)
    session_token = make_session_token(nonce)
    auth_cookie   = cookie_header("_auth", session_token, SESSION_TTL)

    dest = (origin or "") + redirect_path
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "cookies": [auth_cookie],
        "body": json.dumps({"redirect": dest}),
    }


def handler(event: dict, context: object) -> dict:
    path = event.get("rawPath", "")
    if path.endswith("/otp/request"):
        return handle_request(event)
    if path.endswith("/otp/verify"):
        return handle_verify(event)
    return {"statusCode": 404, "headers": {"Content-Type": "text/plain"}, "body": "Not found."}
