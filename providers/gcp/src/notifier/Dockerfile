FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY notifier/main.py ./main.py

ENV PORT=8080
CMD ["functions-framework", "--target=publish_notification", "--port=8080"]
