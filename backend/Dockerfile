# Stage 1: Build Stage
FROM python:3.11-slim as builder
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
WORKDIR /usr/src/app
# Install build dependencies, including non-free for Postgres drivers, gcc for c extensions used by some packages like psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt

# ---
# Stage 2: Final Production Stage (Minimal & Secure) 
# ---
FROM python:3.11-slim
WORKDIR /usr/src/app

# Install only runtime dependencies (Postgres client library)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/requirements.txt .
RUN pip install --no-cache /wheels/*

#  Switch to Non-Root User          
# Created dedicated user/group and set permissions
RUN groupadd -r appuser && useradd -r -g appuser -d /usr/src/app appuser
RUN chown -R appuser:appuser /usr/src/app
USER appuser

COPY . .



EXPOSE 8000

CMD ["gunicorn", "app.main:app", "--bind", "0.0.0.0:8000", "--workers", "3"]