from __future__ import annotations

import os

from apns2.client import APNsClient
from apns2.credentials import TokenCredentials
from apns2.payload import Payload

_client: APNsClient | None = None


def _get_client() -> APNsClient:
    global _client
    if _client is None:
        creds = TokenCredentials(
            auth_key_path=os.environ["APNS_KEY_PATH"],
            auth_key_id=os.environ["APNS_KEY_ID"],
            team_id=os.environ["APNS_TEAM_ID"],
        )
        use_sandbox = os.environ.get("APNS_SANDBOX", "false").lower() == "true"
        _client = APNsClient(
            credentials=creds,
            use_sandbox=use_sandbox,
            use_alternative_port=False,
        )
    return _client


def send_alert(apns_token: str, title: str, body: str):
    bundle_id = os.environ["APNS_BUNDLE_ID"]
    payload = Payload(alert={"title": title, "body": body}, sound="default")
    _get_client().send_notification(apns_token, payload, topic=bundle_id)
