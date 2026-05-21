#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[mtmsub2api] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

DATA_ROOT="${DATA_ROOT:-/data}"
APP_DATA_DIR="${DATA_DIR:-$DATA_ROOT/app}"
PGDATA="${PGDATA:-$DATA_ROOT/postgres}"
REDIS_DATA_DIR="${REDIS_DATA_DIR:-$DATA_ROOT/redis}"
RUN_DIR="$DATA_ROOT/run"
LOG_DIR="$DATA_ROOT/logs"
CONFIG_DIR="$DATA_ROOT/config"

DATABASE_USER="${DATABASE_USER:-sub2api}"
DATABASE_DBNAME="${DATABASE_DBNAME:-sub2api}"
DATABASE_PORT="${DATABASE_PORT:-5432}"
REDIS_PORT="${REDIS_PORT:-6379}"
TZ="${TZ:-Asia/Shanghai}"

POSTGRES_MAX_CONNECTIONS="${POSTGRES_MAX_CONNECTIONS:-256}"
POSTGRES_SHARED_BUFFERS="${POSTGRES_SHARED_BUFFERS:-128MB}"
POSTGRES_EFFECTIVE_CACHE_SIZE="${POSTGRES_EFFECTIVE_CACHE_SIZE:-512MB}"
POSTGRES_MAINTENANCE_WORK_MEM="${POSTGRES_MAINTENANCE_WORK_MEM:-64MB}"
REDIS_MAXCLIENTS="${REDIS_MAXCLIENTS:-10000}"

export DATA_DIR="$APP_DATA_DIR"
export DATABASE_HOST="${DATABASE_HOST:-127.0.0.1}"
export DATABASE_PORT
export DATABASE_USER
export DATABASE_DBNAME
export DATABASE_SSLMODE="${DATABASE_SSLMODE:-disable}"
export REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
export REDIS_PORT
export REDIS_DB="${REDIS_DB:-0}"
export AUTO_SETUP="${AUTO_SETUP:-true}"
export SERVER_HOST="${SERVER_HOST:-0.0.0.0}"
export SERVER_PORT="${SERVER_PORT:-8080}"
export TZ

mkdir -p "$APP_DATA_DIR" "$PGDATA" "$REDIS_DATA_DIR" "$RUN_DIR" "$LOG_DIR" "$CONFIG_DIR" "$DATA_ROOT/backups"
chmod 0755 "$DATA_ROOT" "$RUN_DIR" "$LOG_DIR" "$APP_DATA_DIR" "$REDIS_DATA_DIR" "$CONFIG_DIR" || true
chmod 0700 "$PGDATA" || true
chown -R postgres:postgres "$PGDATA" "$RUN_DIR" || true
if id sub2api >/dev/null 2>&1; then
  chown -R sub2api:sub2api "$APP_DATA_DIR" || true
fi

if [[ -z "${DATABASE_PASSWORD:-}" ]]; then
  secret_file="$CONFIG_DIR/database_password"
  if [[ -s "$secret_file" ]]; then
    DATABASE_PASSWORD="$(<"$secret_file")"
  else
    DATABASE_PASSWORD="$(openssl rand -hex 32)"
    umask 077
    printf '%s' "$DATABASE_PASSWORD" > "$secret_file"
    log "generated DATABASE_PASSWORD at $secret_file"
  fi
fi
export DATABASE_PASSWORD
export POSTGRES_PASSWORD="$DATABASE_PASSWORD"

if [[ -z "${JWT_SECRET:-}" ]]; then
  secret_file="$CONFIG_DIR/jwt_secret"
  if [[ -s "$secret_file" ]]; then
    JWT_SECRET="$(<"$secret_file")"
  else
    JWT_SECRET="$(openssl rand -hex 32)"
    umask 077
    printf '%s' "$JWT_SECRET" > "$secret_file"
    log "generated JWT_SECRET at $secret_file"
  fi
fi
export JWT_SECRET

if [[ -z "${TOTP_ENCRYPTION_KEY:-}" ]]; then
  secret_file="$CONFIG_DIR/totp_encryption_key"
  if [[ -s "$secret_file" ]]; then
    TOTP_ENCRYPTION_KEY="$(<"$secret_file")"
  else
    TOTP_ENCRYPTION_KEY="$(openssl rand -hex 32)"
    umask 077
    printf '%s' "$TOTP_ENCRYPTION_KEY" > "$secret_file"
    log "generated TOTP_ENCRYPTION_KEY at $secret_file"
  fi
fi
export TOTP_ENCRYPTION_KEY

render_template() {
  local src="$1" dst="$2"
  sed \
    -e "s|__DATABASE_PORT__|$DATABASE_PORT|g" \
    -e "s|__POSTGRES_MAX_CONNECTIONS__|$POSTGRES_MAX_CONNECTIONS|g" \
    -e "s|__POSTGRES_SHARED_BUFFERS__|$POSTGRES_SHARED_BUFFERS|g" \
    -e "s|__POSTGRES_EFFECTIVE_CACHE_SIZE__|$POSTGRES_EFFECTIVE_CACHE_SIZE|g" \
    -e "s|__POSTGRES_MAINTENANCE_WORK_MEM__|$POSTGRES_MAINTENANCE_WORK_MEM|g" \
    -e "s|__REDIS_PORT__|$REDIS_PORT|g" \
    -e "s|__REDIS_MAXCLIENTS__|$REDIS_MAXCLIENTS|g" \
    -e "s|__TZ__|$TZ|g" \
    "$src" > "$dst"
}

redis_cli() {
  if [[ -n "${REDIS_PASSWORD:-}" ]]; then
    REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli "$@"
  else
    redis-cli "$@"
  fi
}

render_template /etc/mtmsub2api/postgresql.conf.tpl "$CONFIG_DIR/postgresql.conf"
render_template /etc/mtmsub2api/redis.conf.tpl "$CONFIG_DIR/redis.conf"
chmod 0644 "$CONFIG_DIR/postgresql.conf" "$CONFIG_DIR/redis.conf" || true
if [[ -n "${REDIS_PASSWORD:-}" ]]; then
  printf '\nrequirepass %s\n' "$REDIS_PASSWORD" >> "$CONFIG_DIR/redis.conf"
fi

if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
  log "initializing PostgreSQL data directory"
  su-exec postgres initdb -D "$PGDATA" --encoding=UTF8 --locale=C >/dev/null
fi

log "starting PostgreSQL"
su-exec postgres postgres -D "$PGDATA" -c "config_file=$CONFIG_DIR/postgresql.conf" >>"$LOG_DIR/postgres.log" 2>&1 &
postgres_pid=$!

cleanup() {
  local code=$?
  log "stopping services"
  if [[ -n "${sub2api_pid:-}" ]] && kill -0 "$sub2api_pid" 2>/dev/null; then kill -TERM "$sub2api_pid" 2>/dev/null || true; fi
  if [[ -n "${redis_pid:-}" ]] && kill -0 "$redis_pid" 2>/dev/null; then kill -TERM "$redis_pid" 2>/dev/null || true; fi
  if kill -0 "$postgres_pid" 2>/dev/null; then su-exec postgres pg_ctl -D "$PGDATA" -m fast stop >/dev/null 2>&1 || kill -TERM "$postgres_pid" 2>/dev/null || true; fi
  exit "$code"
}
trap cleanup INT TERM EXIT

for _ in $(seq 1 60); do
  if pg_isready -h 127.0.0.1 -p "$DATABASE_PORT" -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
pg_isready -h 127.0.0.1 -p "$DATABASE_PORT" -U postgres >/dev/null 2>&1 || die "PostgreSQL did not become ready"

if ! su-exec postgres psql -h 127.0.0.1 -p "$DATABASE_PORT" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DATABASE_USER}'" | grep -q 1; then
  log "creating PostgreSQL role $DATABASE_USER"
  su-exec postgres psql -h 127.0.0.1 -p "$DATABASE_PORT" -v ON_ERROR_STOP=1 -c "CREATE ROLE \"$DATABASE_USER\" LOGIN PASSWORD '$DATABASE_PASSWORD';" >/dev/null
fi
if ! su-exec postgres psql -h 127.0.0.1 -p "$DATABASE_PORT" -tAc "SELECT 1 FROM pg_database WHERE datname='${DATABASE_DBNAME}'" | grep -q 1; then
  log "creating PostgreSQL database $DATABASE_DBNAME"
  su-exec postgres createdb -h 127.0.0.1 -p "$DATABASE_PORT" -O "$DATABASE_USER" "$DATABASE_DBNAME"
fi

log "starting Redis"
redis-server "$CONFIG_DIR/redis.conf" >>"$LOG_DIR/redis.log" 2>&1 &
redis_pid=$!
for _ in $(seq 1 30); do
  if redis_cli -h 127.0.0.1 -p "$REDIS_PORT" ping >/dev/null 2>&1; then break; fi
  sleep 1
done
redis_cli -h 127.0.0.1 -p "$REDIS_PORT" ping >/dev/null 2>&1 || die "Redis did not become ready"

log "starting sub2api: $*"
"$@" >>"$LOG_DIR/sub2api.log" 2>&1 &
sub2api_pid=$!
wait "$sub2api_pid"
