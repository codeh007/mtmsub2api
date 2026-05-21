# mtmsub2api

Public all-in-one Docker image for running [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api) as a single-container service.

This image is built on top of `docker.io/gitgit188/gomtm`, the shared gomtm runtime base image. It copies the upstream sub2api binary from the official upstream image, then adds only the service-specific PostgreSQL, Redis, entrypoint, healthcheck, and backup logic.

## Image

GitHub Actions publishes:

```text
ghcr.io/codeh007/mtmsub2api:latest
ghcr.io/codeh007/mtmsub2api:<git-sha>
```

## Quick start

```bash
docker volume create mtmsub2api-data

docker run -d \
  --name mtmsub2api \
  --restart unless-stopped \
  -p 127.0.0.1:8080:8080 \
  -v mtmsub2api-data:/data \
  -e ADMIN_EMAIL=admin@example.com \
  -e ADMIN_PASSWORD='change-this-password' \
  ghcr.io/codeh007/mtmsub2api:latest
```

Then check:

```bash
curl -fsS http://127.0.0.1:8080/health
```

## Data layout

```text
/data/
  app/          # sub2api DATA_DIR
  postgres/     # PostgreSQL PGDATA
  redis/        # Redis AOF/RDB data
  backups/      # backups created by mtmsub2api-backup
  logs/         # postgres.log, redis.log, sub2api.log
  run/          # local sockets/runtime files
  config/       # generated configs and generated secrets
```

## Important environment variables

| Variable | Default | Notes |
| --- | --- | --- |
| `ADMIN_EMAIL` | upstream default | Set for production |
| `ADMIN_PASSWORD` | upstream generated/empty behavior | Set for production |
| `JWT_SECRET` | generated under `/data/config/jwt_secret` | Set explicitly for production or persist `/data` |
| `TOTP_ENCRYPTION_KEY` | generated under `/data/config/totp_encryption_key` | Persist `/data` or set explicitly |
| `DATABASE_PASSWORD` | generated under `/data/config/database_password` | Internal Postgres password |
| `REDIS_PASSWORD` | empty | Optional internal Redis password |
| `SERVER_PORT` | `8080` | sub2api internal port |
| `TZ` | `Asia/Shanghai` | timezone |

Secret values are never printed by the entrypoint. If omitted, generated secrets are stored under `/data/config`; therefore `/data` must be persistent.

## Backup

Inside the container:

```bash
docker exec mtmsub2api mtmsub2api-backup
```

The backup includes a PostgreSQL custom-format dump and app/redis/config data archive.

## Safety

- Do not mount this image directly over an existing production `~/.sub2api` compose directory.
- Migrate from compose only after inventory, backup, isolated restore test, and external verification.
- Do not delete old compose volumes/data until the new container has been verified and rollback is no longer needed.
