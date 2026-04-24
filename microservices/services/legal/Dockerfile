FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SERVICE_NAME=legal-service

WORKDIR /app

# Install shared package first
COPY shared /tmp/shared
RUN pip install --no-cache-dir /tmp/shared && rm -rf /tmp/shared

COPY services/legal/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY services/legal/ .

RUN python manage.py collectstatic --noinput 2>/dev/null || true

EXPOSE 8000

CMD ["sh", "-c", "python manage.py migrate --noinput && gunicorn --bind 0.0.0.0:8000 --workers 3 --timeout 120 legal_service.wsgi:application"]
