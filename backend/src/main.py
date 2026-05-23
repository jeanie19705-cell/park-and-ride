import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI

load_dotenv()

from db.client import close_pool, get_pool
from middleware.api_key import APIKeyMiddleware
from routes import alerts, carparks, devices
from services import scheduler

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await get_pool()
    sched = scheduler.start()
    yield
    sched.shutdown(wait=False)
    await close_pool()


app = FastAPI(title="Park & Ride API", lifespan=lifespan)
app.add_middleware(APIKeyMiddleware)

app.include_router(devices.router)
app.include_router(alerts.router)
app.include_router(carparks.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
