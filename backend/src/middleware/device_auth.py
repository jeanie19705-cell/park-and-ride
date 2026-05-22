from fastapi import Header, HTTPException


async def require_device_id(x_device_id: str = Header(...)) -> str:
    if not x_device_id.strip():
        raise HTTPException(status_code=400, detail="x-device-id header is required")
    return x_device_id
