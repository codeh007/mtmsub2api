#!/usr/bin/env bash
set -euo pipefail
DATA_ROOT="${DATA_ROOT:-/data}"
DATABASE_PORT="${DATABASE_PORT:-5432}"
DATABASE_USER="${DATABASE_USER:-sub2api}"
DATABASE_DBNAME="${DATABASE_DBNAME:-sub2api}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="$DATA_ROOT/backups/$stamp"
mkdir -p "$out_dir"
chmod 0700 "$out_dir"
PGPASSWORD="${DATABASE_PASSWORD:-${POSTGRES_PASSWORD:-}}" pg_dump \
  -h 127.0.0.1 -p "$DATABASE_PORT" -U "$DATABASE_USER" -d "$DATABASE_DBNAME" \
  --format=custom --no-owner --file "$out_dir/postgres.dump"
tar czf "$out_dir/app-data.tar.gz" -C "$DATA_ROOT" app redis config
( cd "$out_dir" && sha256sum postgres.dump app-data.tar.gz > SHA256SUMS )
archive="$DATA_ROOT/backups/mtmsub2api-$stamp.tar.gz"
tar czf "$archive" -C "$DATA_ROOT/backups" "$stamp"
printf '%s\n' "$archive"
