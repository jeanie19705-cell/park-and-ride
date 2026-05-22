import logging
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from db.client import get_pool
from services import apns, tfnsw

logger = logging.getLogger(__name__)


async def _fetch_carparks():
    """Job 1: Pull latest data from TfNSW and cache it in the DB."""
    try:
        parks = await tfnsw.fetch_all()
    except Exception as exc:
        logger.error("TfNSW fetch failed: %s", exc)
        return

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.executemany(
            """
            INSERT INTO carparks (facility_id, facility_name, available_spots, total_spots, updated_at)
            VALUES ($1, $2, $3, $4, NOW())
            ON CONFLICT (facility_id)
            DO UPDATE SET
                facility_name   = $2,
                available_spots = $3,
                total_spots     = $4,
                updated_at      = NOW()
            """,
            [(p.facility_id, p.facility_name, p.available_spots, p.total_spots) for p in parks],
        )
    logger.info("Carpark cache updated: %d parks", len(parks))


async def _evaluate_alerts():
    """Job 2: Join alerts with cached carpark data and push notify where needed."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                a.id, a.device_id, a.facility_id, a.threshold,
                a.start_hour, a.start_minute, a.end_hour, a.end_minute,
                d.apns_token,
                c.facility_name, c.available_spots, c.total_spots
            FROM alerts a
            JOIN devices d  ON d.id = a.device_id
            JOIN carparks c ON c.facility_id = a.facility_id
            WHERE a.is_enabled = TRUE
              AND c.total_spots > 0
            """
        )

        now = datetime.now(timezone.utc).astimezone()
        current_minutes = now.hour * 60 + now.minute

        for row in rows:
            start = row["start_hour"] * 60 + row["start_minute"]
            end = row["end_hour"] * 60 + row["end_minute"]
            if not (start <= current_minutes <= end):
                continue

            available_pct = int(row["available_spots"] / row["total_spots"] * 100)
            is_below = available_pct < row["threshold"]

            logger.info(
                "[alert check] device=%s facility=%s (%s) available=%d%% threshold=%d%% firing=%s",
                row["device_id"], row["facility_id"], row["facility_name"],
                available_pct, row["threshold"], is_below,
            )

            state = await conn.fetchrow(
                "SELECT is_firing FROM alert_state WHERE device_id=$1 AND facility_id=$2",
                row["device_id"], row["facility_id"],
            )
            was_firing = state["is_firing"] if state else False

            if is_below and not was_firing:
                await conn.execute(
                    """
                    INSERT INTO alert_state (device_id, facility_id, is_firing, updated_at)
                    VALUES ($1, $2, TRUE, NOW())
                    ON CONFLICT (device_id, facility_id)
                    DO UPDATE SET is_firing = TRUE, updated_at = NOW()
                    """,
                    row["device_id"], row["facility_id"],
                )
                logger.info(
                    "[alert FIRE] → device=%s facility=%s apns_token=%s msg='%d%% available'",
                    row["device_id"], row["facility_id"], row["apns_token"], available_pct,
                )
                try:
                    apns.send_alert(
                        apns_token=row["apns_token"],
                        title=row["facility_name"] or "Park & Ride",
                        body=f"Only {available_pct}% available — {row['available_spots']} of {row['total_spots']} spaces left.",
                    )
                except Exception as exc:
                    logger.error("APNs send failed for %s: %s", row["facility_id"], exc)

            elif not is_below and was_firing:
                logger.info(
                    "[alert RESET] device=%s facility=%s recovered to %d%%",
                    row["device_id"], row["facility_id"], available_pct,
                )
                await conn.execute(
                    """
                    INSERT INTO alert_state (device_id, facility_id, is_firing, updated_at)
                    VALUES ($1, $2, FALSE, NOW())
                    ON CONFLICT (device_id, facility_id)
                    DO UPDATE SET is_firing = FALSE, updated_at = NOW()
                    """,
                    row["device_id"], row["facility_id"],
                )


def start() -> AsyncIOScheduler:
    scheduler = AsyncIOScheduler()
    scheduler.add_job(_fetch_carparks, "interval", seconds=60, id="fetch_carparks")
    scheduler.add_job(_evaluate_alerts, "interval", seconds=60, id="evaluate_alerts",
                      start_date="2000-01-01 00:00:05")  # 5s offset so data is ready first
    scheduler.start()
    return scheduler
