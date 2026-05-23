from fastapi import APIRouter, HTTPException

from db.client import get_pool

router = APIRouter(prefix="/carparks", tags=["carparks"])

_COLS = "facility_id, facility_name, available_spots, total_spots, suburb, address, latitude, longitude, updated_at"


@router.get("")
async def list_carparks():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(f"SELECT {_COLS} FROM carparks ORDER BY facility_name")
    return [dict(r) for r in rows]


@router.get("/{facility_id}")
async def get_carpark(facility_id: str):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            f"SELECT {_COLS} FROM carparks WHERE facility_id = $1", facility_id
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Car park not found")
    return dict(row)


@router.get("/{facility_id}/history")
async def get_carpark_history(facility_id: str):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT timestamp, available, total
            FROM occupancy_readings
            WHERE facility_id = $1
              AND timestamp >= NOW() - INTERVAL '24 hours'
            ORDER BY timestamp ASC
            """,
            facility_id,
        )
    return [
        {
            "timestamp": r["timestamp"].isoformat(),
            "available": r["available"],
            "total": r["total"],
            "occupancy_fraction": round(1 - r["available"] / r["total"], 4) if r["total"] else None,
        }
        for r in rows
    ]
