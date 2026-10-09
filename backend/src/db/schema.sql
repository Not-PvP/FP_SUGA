-- SUGA database schema
-- Areas have many feeders. A power interruption can affect many areas
-- and many feeders, so those links live in join tables.

CREATE TABLE IF NOT EXISTS areas (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  city        TEXT    NOT NULL,
  latitude    REAL    NOT NULL,
  longitude   REAL    NOT NULL,
  created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (name, city)
);

CREATE TABLE IF NOT EXISTS feeders (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  area_id     INTEGER NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL UNIQUE,
  created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS power_interruptions (
  id                     INTEGER PRIMARY KEY AUTOINCREMENT,
  title                  TEXT NOT NULL,
  description            TEXT NOT NULL DEFAULT '',
  date                   TEXT NOT NULL,              -- YYYY-MM-DD
  start_time             TEXT NOT NULL,              -- HH:MM (24-hour)
  end_time               TEXT NOT NULL,              -- HH:MM (24-hour)
  reason                 TEXT NOT NULL DEFAULT '',
  status                 TEXT NOT NULL DEFAULT 'scheduled'
                         CHECK (status IN ('scheduled', 'ongoing', 'restored', 'cancelled')),
  estimated_restoration  TEXT,                       -- HH:MM, optional
  created_at             TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS interruption_areas (
  interruption_id  INTEGER NOT NULL REFERENCES power_interruptions(id) ON DELETE CASCADE,
  area_id          INTEGER NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
  PRIMARY KEY (interruption_id, area_id)
);

CREATE TABLE IF NOT EXISTS interruption_feeders (
  interruption_id  INTEGER NOT NULL REFERENCES power_interruptions(id) ON DELETE CASCADE,
  feeder_id        INTEGER NOT NULL REFERENCES feeders(id) ON DELETE CASCADE,
  PRIMARY KEY (interruption_id, feeder_id)
);

CREATE INDEX IF NOT EXISTS idx_feeders_area ON feeders(area_id);
CREATE INDEX IF NOT EXISTS idx_interruptions_date ON power_interruptions(date);
CREATE INDEX IF NOT EXISTS idx_interruption_areas_area ON interruption_areas(area_id);
CREATE INDEX IF NOT EXISTS idx_interruption_feeders_feeder ON interruption_feeders(feeder_id);

-- Keep updated_at current whenever a row changes.
CREATE TRIGGER IF NOT EXISTS trg_areas_updated_at
AFTER UPDATE ON areas FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE areas SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_feeders_updated_at
AFTER UPDATE ON feeders FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE feeders SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_interruptions_updated_at
AFTER UPDATE ON power_interruptions FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE power_interruptions SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
