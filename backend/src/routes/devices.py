from fastapi import APIRouter
from pydantic import BaseModel

from db.client import get_pool

router = APIRouter(prefix="/devices", tags=["devices"])


class RegisterRequest(BaseModel):
    device_id: str
    apns_token: str


@router.post("", status_code=204)
async def register_device(body: RegisterRequest):
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO devices (id, apns_token, updated_at)
            VALUES ($1, $2, NOW())
            ON CONFLICT (id)
            DO UPDATE SET apns_token = $2, updated_at = NOW()
            """,
            body.device_id, body.apns_token,
        )
