-- Notes app schema for PostgreSQL
-- This script is idempotent where possible and safe to re-run.

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Updated timestamps helper
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- USERS
CREATE TABLE IF NOT EXISTS app_user (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- NOTES
CREATE TABLE IF NOT EXISTS note (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content_markdown TEXT NOT NULL DEFAULT '',
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_note_set_updated_at'
  ) THEN
    CREATE TRIGGER tr_note_set_updated_at
    BEFORE UPDATE ON note
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_note_user_updated_at ON note(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_note_user_pinned ON note(user_id, is_pinned, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_note_user_favorite ON note(user_id, is_favorite, updated_at DESC);

-- TAGS
CREATE TABLE IF NOT EXISTS tag (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_tag_user_name ON tag(user_id, name);

-- NOTE <-> TAG JOIN
CREATE TABLE IF NOT EXISTS note_tag (
  note_id UUID NOT NULL REFERENCES note(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (note_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_note_tag_tag_id ON note_tag(tag_id);
CREATE INDEX IF NOT EXISTS idx_note_tag_note_id ON note_tag(note_id);
