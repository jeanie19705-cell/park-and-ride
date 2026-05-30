from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from db.client import get_pool
from middleware.device_auth import require_device_id

router = APIRouter(prefix="/alerts", tags=["alerts"])


class AlertBody(BaseModel):
    facility_id: str
    threshold: int = Field(..., ge=0, le=100)
    start_hour: int = Field(..., ge=0, le=23)
    start_minute: int = Field(..., ge=0, le=59)
    end_hour: int = Field(..., ge=0, le=23)
    end_minute: int = Field(..., ge=0, le=59)
    is_enabled: bool = True


@router.get("")
async def list_alerts(device_id: str = Depends(require_device_id)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM alerts WHERE device_id = $1 ORDER BY created_at", device_id
        )
    return [dict(r) for r in rows]


@router.post("", status_code=201)
async def create_alert(body: AlertBody, device_id: str = Depends(require_device_id)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO alerts
                (device_id, facility_id, threshold, start_hour, start_minute,
                 end_hour, end_minute, is_enabled)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (device_id, facility_id)
            DO UPDATE SET
                threshold = $3, start_hour = $4, start_minute = $5,
                end_hour = $6, end_minute = $7, is_enabled = $8, updated_at = NOW()
            RETURNING *
            """,
            device_id, body.facility_id, body.threshold,
            body.start_hour, body.start_minute,
            body.end_hour, body.end_minute, body.is_enabled,
        )
        if not body.is_enabled:
            await conn.execute(
                """
                UPDATE alert_state SET is_firing = FALSE, updated_at = NOW()
                WHERE device_id = $1 AND facility_id = $2
                """,
                device_id, body.facility_id,
            )
    return dict(row)


@router.put("/{alert_id}")
async def update_alert(
    alert_id: UUID,
    body: AlertBody,
    device_id: str = Depends(require_device_id),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            UPDATE alerts
            SET threshold = $3, start_hour = $4, start_minute = $5,
                end_hour = $6, end_minute = $7, is_enabled = $8, updated_at = NOW()
            WHERE id = $1 AND device_id = $2
            RETURNING *
            """,
            alert_id, device_id, body.threshold,
            body.start_hour, body.start_minute,
            body.end_hour, body.end_minute, body.is_enabled,
        )
        if row is None:
            raise HTTPException(status_code=404, detail="Alert not found")
        if not body.is_enabled:
            await conn.execute(
                """
                UPDATE alert_state SET is_firing = FALSE, updated_at = NOW()
                WHERE device_id = $1 AND facility_id = $2
                """,
                device_id, row["facility_id"],
            )
    return dict(row)


@router.delete("/{alert_id}", status_code=204)
async def delete_alert(alert_id: UUID, device_id: str = Depends(require_device_id)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM alerts WHERE id = $1 AND device_id = $2", alert_id, device_id
        )
    if result == "DELETE 0":
        raise HTTPException(status_code=404, detail="Alert not found")
