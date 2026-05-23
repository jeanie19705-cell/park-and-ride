import os

from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware


class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path == "/health":
            return await call_next(request)

        expected = os.environ.get("API_KEY", "")
        provided = request.headers.get("x-api-key", "")

        if not expected or provided != expected:
            raise HTTPException(status_code=401, detail="Invalid or missing API key")

        return await call_next(request)
