bind 127.0.0.1
port __REDIS_PORT__
dir /data/redis
appendonly yes
appendfsync everysec
save 60 1
maxclients __REDIS_MAXCLIENTS__
protected-mode yes
