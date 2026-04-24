FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SERVICE_NAME=notifications-service

WORKDIR /app

COPY shared /tmp/shared
RUN pip install --no-cache-dir /tmp/shared && rm -rf /tmp/shared

COPY services/notifications/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY services/notifications/ .

EXPOSE 8000

CMD ["sh", "-c", "python manage.py migrate --noinput && gunicorn --bind 0.0.0.0:8000 --workers 2 --timeout 120 notifications_service.wsgi:application"]
