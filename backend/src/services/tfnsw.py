from __future__ import annotations

import os
from dataclasses import dataclass

import httpx

TFNSW_URL = "https://api.transport.nsw.gov.au/v1/carpark/full-list"


@dataclass
class CarPark:
    facility_id: str
    facility_name: str | None
    available_spots: int | None
    total_spots: int | None
    suburb: str | None
    address: str | None
    latitude: str | None
    longitude: str | None


def _int(val) -> int | None:
    try:
        return int(val) if val is not None else None
    except (ValueError, TypeError):
        return None


async def fetch_all() -> list[CarPark]:
    api_key = os.environ["TFNSW_API_KEY"]
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            TFNSW_URL,
            headers={"Authorization": f"apikey {api_key}"},
        )
        resp.raise_for_status()
        data = resp.json()

    parks = []
    for item in data:
        total = _int(item.get("spots"))
        occupied = _int(item.get("occupancy", {}).get("total"))
        available = (total - occupied) if (total is not None and occupied is not None) else None
        loc = item.get("location", {}) or {}
        parks.append(CarPark(
            facility_id=str(item.get("facility_id", "")),
            facility_name=item.get("facility_name"),
            available_spots=available,
            total_spots=total,
            suburb=loc.get("suburb"),
            address=loc.get("address"),
            latitude=loc.get("latitude"),
            longitude=loc.get("longitude"),
        ))
    return parks
