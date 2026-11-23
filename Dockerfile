# ---------- Task Manager API image ----------
FROM python:3.12-slim

# Build info passed in by Jenkins (shown at /api/version)
ARG BUILD_NUMBER=local
ARG GIT_COMMIT=unknown
ARG APP_VERSION=1.0.0
ENV BUILD_NUMBER=${BUILD_NUMBER} \
    GIT_COMMIT=${GIT_COMMIT} \
    APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first so Docker can cache this layer between builds
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Don't run as root inside the container
RUN useradd --create-home appuser
USER appuser

EXPOSE 5000

# Docker marks the container unhealthy if /health stops responding
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health', timeout=2)"

# 1 worker with 4 threads: tasks live in memory, so one process keeps them consistent
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "app:app"]
