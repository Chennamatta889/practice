# Build/compile stage; both bases use a fixed version, not 'latest'.
FROM python:3.12.9-slim-bookworm AS builder
WORKDIR /build
COPY app.py /build/app.py
RUN python -m compileall -q /build/app.py

# Runtime stage. Do not ship build caches and do not run as root.
FROM python:3.12.9-slim-bookworm
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PORT=8080
RUN groupadd --system --gid 10001 app && \
    useradd --system --uid 10001 --gid 10001 --home-dir /nonexistent --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=builder --chown=10001:10001 /build/app.py /app/app.py
USER 10001:10001
EXPOSE 8080
CMD ["python", "-B", "/app/app.py"]
