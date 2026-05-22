from fastapi import APIRouter, HTTPException

from db.client import get_pool

router = APIRouter(prefix="/carparks", tags=["carparks"])


@router.get("")
async def list_carparks():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT facility_id, facility_name, available_spots, total_spots, updated_at FROM carparks ORDER BY facility_name"
        )
    return [dict(r) for r in rows]


@router.get("/{facility_id}")
async def get_carpark(facility_id: str):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT facility_id, facility_name, available_spots, total_spots, updated_at FROM carparks WHERE facility_id = $1",
            facility_id,
        )
    if row is None:
        raise HTTPException(status_code=404, detail="Car park not found")
    return dict(row)
