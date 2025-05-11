FROM alpine:3.19

# Install bash, curl, jq
RUN apk add --no-cache bash curl jq

# Copy script
COPY replicaset-scale-watcher.sh /scripts/replicaset-scale-watcher.sh
RUN chmod +x /scripts/replicaset-scale-watcher.sh

ENTRYPOINT ["/scripts/replicaset-scale-watcher.sh"]
