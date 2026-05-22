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

    @property
    def occupancy_pct(self) -> int | None:
        if self.available_spots is None or self.total_spots is None or self.total_spots == 0:
            return None
        return int((1 - self.available_spots / self.total_spots) * 100)


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
        data = resp.json()  # list of carpark dicts

    parks = []
    for item in data:
        total = _int(item.get("spots"))
        occupied = _int(item.get("occupancy", {}).get("total"))
        available = (total - occupied) if (total is not None and occupied is not None) else None
        parks.append(CarPark(
            facility_id=str(item.get("facility_id", "")),
            facility_name=item.get("facility_name"),
            available_spots=available,
            total_spots=total,
        ))
    return parks
