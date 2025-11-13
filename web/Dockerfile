FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=app.py \
    FLASK_RUN_HOST=0.0.0.0 \
    FLASK_ENV=production

EXPOSE 5000

# Increase timeout to avoid worker restarts if the first call waits on storage/emulator
CMD ["gunicorn", "-b", "0.0.0.0:5000", "--workers", "2", "--timeout", "120", "app:app"]
