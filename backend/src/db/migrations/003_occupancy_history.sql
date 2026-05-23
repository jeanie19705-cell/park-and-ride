CREATE TABLE occupancy_readings (
    facility_id  TEXT        NOT NULL REFERENCES carparks(facility_id),
    timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    available    INTEGER     NOT NULL,
    total        INTEGER     NOT NULL
);

CREATE INDEX idx_occupancy_readings_facility_time
    ON occupancy_readings (facility_id, timestamp DESC);
