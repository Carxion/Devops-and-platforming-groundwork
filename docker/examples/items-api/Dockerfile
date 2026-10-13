# syntax=docker/dockerfile:1
#
# The api-testing reference server (api-testing/local-server/items_server.py)
# as a small, non-root image. Build from the repository root:
#
#   docker build -f docker/examples/items-api/Dockerfile -t items-api api-testing/local-server
#   docker run --rm -p 8080:8080 items-api
#
# Each choice here is explained in docker/02-dockerfiles.md.

# Pin the base by digest as well as tag: the tag is for people, the digest is
# what's actually pulled, so a rebuild can't silently get a different image.
FROM python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170

# Labels from the OCI image spec: where it came from, for scanners and people.
LABEL org.opencontainers.image.title="items-api" \
      org.opencontainers.image.description="In-memory reference implementation of the Items API" \
      org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork" \
      org.opencontainers.image.licenses="MIT"

# Python runtime settings: no .pyc files, and unbuffered output so logs reach
# "docker logs" immediately.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# A fixed, unprivileged user. A numeric UID lets Kubernetes verify
# runAsNonRoot without reading /etc/passwd inside the image.
# The app uses only the standard library, so remove pip as well: it isn't
# needed at runtime, and its vendored libraries were the image's only
# scanner findings.
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app \
 && python -m pip uninstall --yes --quiet pip

WORKDIR /app
# Copy only what the app needs, owned by root and read-only to the app user,
# so a compromised process can't rewrite its own code.
COPY --chmod=0444 items_server.py ./

USER 10001:10001
EXPOSE 8080

# Docker's own health check (Kubernetes ignores it and uses probes instead).
# Standard library only, because slim images have no curl. Any HTTP answer,
# including the 404 for a missing item, means the server is up.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request, urllib.error\ntry:\n urllib.request.urlopen('http://127.0.0.1:8080/items/health', timeout=2)\nexcept urllib.error.HTTPError:\n pass"]

# Exec form (a JSON array): the app is PID 1 and receives SIGTERM directly,
# so "docker stop" shuts it down cleanly instead of killing it after 10 s.
ENTRYPOINT ["python", "items_server.py"]
CMD ["--host", "0.0.0.0", "--port", "8080"]
