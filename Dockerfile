# syntax=docker/dockerfile:1.7
ARG SUB2API_IMAGE=weishaw/sub2api:latest
FROM ${SUB2API_IMAGE}

USER root

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    openssl \
    postgresql17 \
    postgresql17-client \
    redis \
    supervisor \
    su-exec \
    tini \
    tzdata \
    && mkdir -p /etc/mtmsub2api /usr/local/bin

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

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/mtmsub2api-entrypoint"]
CMD ["/app/sub2api"]
