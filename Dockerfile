# Use Python 3.11 slim as the base image
FROM python:3.11-slim AS builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Final stage
FROM python:3.11-slim

# Create a non-root user
RUN useradd -m appuser

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels from builder
COPY --from=builder /app/wheels /wheels
COPY --from=builder /app/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache /wheels/*

# Copy project files
COPY . .

# Set permissions
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set environment variables for Django (for build-time operations)
ENV DJANGO_SETTINGS_MODULE=rapid.settings \
    DEBUG=False \
    ALLOWED_HOSTS='*' \
    SECRET_KEY="dummy-secret-key-for-build" \
    SOCIAL_AUTH_GOOGLE_OAUTH2_KEY="dummy-google-key-for-build" \
    SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET="dummy-google-secret-for-build" \
    STRIPE_PUBLIC_KEY="dummy-stripe-public-key-for-build" \
    STRIPE_SECRET_KEY="dummy-stripe-secret-key-for-build"

# Collect static files (only if static files exist)
RUN python manage.py collectstatic --noinput || true

# Run migrations
RUN python manage.py migrate --noinput

# Expose port
EXPOSE 8000

# Run gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "rapid.wsgi:application"]