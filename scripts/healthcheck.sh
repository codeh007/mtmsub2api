#!/usr/bin/env bash
set -euo pipefail
DATA_ROOT="${DATA_ROOT:-/data}"
DATABASE_PORT="${DATABASE_PORT:-5432}"
DATABASE_USER="${DATABASE_USER:-sub2api}"
DATABASE_DBNAME="${DATABASE_DBNAME:-sub2api}"
REDIS_PORT="${REDIS_PORT:-6379}"
SERVER_PORT="${SERVER_PORT:-8080}"

pg_isready -h 127.0.0.1 -p "$DATABASE_PORT" -U "$DATABASE_USER" -d "$DATABASE_DBNAME" >/dev/null
if [ -n "${REDIS_PASSWORD:-}" ]; then
  REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h 127.0.0.1 -p "$REDIS_PORT" ping | grep -q PONG
else
  redis-cli -h 127.0.0.1 -p "$REDIS_PORT" ping | grep -q PONG
fi
curl -fsS "http://127.0.0.1:${SERVER_PORT}/health" | grep -q 'ok'
