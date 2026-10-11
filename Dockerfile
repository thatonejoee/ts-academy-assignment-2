# Lightweight base image (about 8 MB)
FROM alpine:3.20

LABEL org.opencontainers.image.title="diagnostic-tool" \
      org.opencontainers.image.description="Dockerized Bash diagnostic CLI" \
      org.opencontainers.image.licenses="MIT"

# Install only what the scripts need:
#   bash       - the scripts use Bash features ([[ ]], regex matching)
#   musl-utils - provides getent for hostname resolution
# --no-cache keeps the package index out of the image layer.
RUN apk add --no-cache bash musl-utils

# Run as an unprivileged user instead of root.
RUN adduser -D -u 10001 appuser

WORKDIR /app

# Copy only the application code, then make it executable.
COPY app/ /app/
RUN chmod 0755 /app/*.sh \
    && ln -s /app/diagnostic.sh /usr/local/bin/diagnostic

USER appuser

# One-shot CLI: the healthcheck verifies the tool is installed and working.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD ["/app/health-check.sh"]

# ENTRYPOINT is the program; CMD is the default argument.
#   docker run diagnostic-tool          -> diagnostic.sh help
#   docker run diagnostic-tool system   -> diagnostic.sh system
ENTRYPOINT ["/app/diagnostic.sh"]
CMD ["help"]
