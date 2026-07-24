FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY ingress/main.py ./main.py

ENV PORT=8080
CMD ["functions-framework", "--target=create_order", "--port=8080"]
