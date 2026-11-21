# Keep runtime small, unprivileged, and pinned to explicit Python and Alpine versions.
FROM python:3.12.16-alpine3.23 AS builder
WORKDIR /build
COPY app.py /build/app.py
RUN python -m compileall -q /build/app.py

FROM python:3.12.16-alpine3.23
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PORT=8080
RUN apk upgrade --no-cache && addgroup -S -g 10001 app && adduser -S -u 10001 -G app -h /nonexistent app
WORKDIR /app
COPY --from=builder --chown=10001:10001 /build/app.py /app/app.py
USER 10001:10001
EXPOSE 8080
CMD ["python", "-B", "/app/app.py"]
