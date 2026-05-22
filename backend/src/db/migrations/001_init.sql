CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE carparks (
  facility_id      TEXT PRIMARY KEY,
  facility_name    TEXT,
  available_spots  INTEGER,
  total_spots      INTEGER,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE devices (
  id          TEXT PRIMARY KEY,
  apns_token  TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE alerts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id    TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  facility_id  TEXT NOT NULL,
  threshold    INTEGER NOT NULL,        -- % occupancy threshold (0-100)
  start_hour   INTEGER NOT NULL,
  start_minute INTEGER NOT NULL,
  end_hour     INTEGER NOT NULL,
  end_minute   INTEGER NOT NULL,
  is_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (device_id, facility_id)
);

-- tracks which alerts have already fired so we don't spam
CREATE TABLE alert_state (
  device_id    TEXT NOT NULL,
  facility_id  TEXT NOT NULL,
  is_firing    BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (device_id, facility_id)
);
