from __future__ import annotations

import os
import time

import httpx
import jwt


def _make_jwt() -> str:
    token = jwt.encode(
        {"iss": os.environ["APNS_TEAM_ID"], "iat": int(time.time())},
        os.environ["APNS_KEY"].replace("\\n", "\n"),
        algorithm="ES256",
        headers={"kid": os.environ["APNS_KEY_ID"]},
    )
    return token if isinstance(token, str) else token.decode()


async def send_alert(apns_token: str, title: str, body: str):
    use_sandbox = os.environ.get("APNS_SANDBOX", "false").lower() == "true"
    host = "api.sandbox.push.apple.com" if use_sandbox else "api.push.apple.com"

    async with httpx.AsyncClient(http2=True) as client:
        resp = await client.post(
            f"https://{host}/3/device/{apns_token}",
            json={"aps": {"alert": {"title": title, "body": body}, "sound": "default"}},
            headers={
                "authorization": f"bearer {_make_jwt()}",
                "apns-topic": os.environ["APNS_BUNDLE_ID"],
                "apns-push-type": "alert",
            },
        )
        resp.raise_for_status()
