# syntax=docker/dockerfile:1.7
ARG SUB2API_IMAGE=weishaw/sub2api:latest
FROM ${SUB2API_IMAGE} AS sub2api-source

FROM docker.io/gitgit188/gomtm:latest

COPY --from=sub2api-source /app/sub2api /app/sub2api
COPY --from=sub2api-source /app/docker-entrypoint.sh /app/docker-entrypoint.sh

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bash \
    curl \
    jq \
    openssl \
    postgresql \
    postgresql-client \
    redis-server \
    gosu \
    tini \
    tzdata \
    && mkdir -p /etc/mtmsub2api /usr/local/bin /app \
    && if ! getent group sub2api >/dev/null; then groupadd --system sub2api; fi \
    && if ! id sub2api >/dev/null 2>&1; then useradd --system --gid sub2api --home-dir /app --shell /usr/sbin/nologin sub2api; fi \
    && ln -sf /usr/lib/postgresql/*/bin/initdb /usr/local/bin/initdb \
    && ln -sf /usr/lib/postgresql/*/bin/postgres /usr/local/bin/postgres \
    && ln -sf /usr/lib/postgresql/*/bin/pg_ctl /usr/local/bin/pg_ctl \
    && ln -sf /usr/lib/postgresql/*/bin/pg_isready /usr/local/bin/pg_isready \
    && ln -sf /usr/lib/postgresql/*/bin/createdb /usr/local/bin/createdb \
    && ln -sf /usr/lib/postgresql/*/bin/psql /usr/local/bin/psql \
    && ln -sf /usr/lib/postgresql/*/bin/pg_dump /usr/local/bin/pg_dump \
    && chown -R sub2api:sub2api /app \
    && rm -rf /var/lib/apt/lists/*

COPY templates/postgresql.conf.tpl /etc/mtmsub2api/postgresql.conf.tpl
COPY templates/redis.conf.tpl /etc/mtmsub2api/redis.conf.tpl
COPY scripts/entrypoint.sh /usr/local/bin/mtmsub2api-entrypoint
COPY scripts/healthcheck.sh /usr/local/bin/mtmsub2api-healthcheck
COPY scripts/backup.sh /usr/local/bin/mtmsub2api-backup

RUN chmod 0755 \
    /usr/local/bin/mtmsub2api-entrypoint \
    /usr/local/bin/mtmsub2api-healthcheck \
    /usr/local/bin/mtmsub2api-backup

ENV DATA_ROOT=/data \
    DATA_DIR=/data/app \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8080 \
    DATABASE_HOST=127.0.0.1 \
    DATABASE_PORT=5432 \
    DATABASE_USER=sub2api \
    DATABASE_DBNAME=sub2api \
    DATABASE_SSLMODE=disable \
    REDIS_HOST=127.0.0.1 \
    REDIS_PORT=6379 \
    REDIS_DB=0 \
    AUTO_SETUP=true \
    TZ=Asia/Shanghai

VOLUME ["/data"]
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
  CMD /usr/local/bin/mtmsub2api-healthcheck

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/mtmsub2api-entrypoint"]
CMD ["/app/sub2api"]
