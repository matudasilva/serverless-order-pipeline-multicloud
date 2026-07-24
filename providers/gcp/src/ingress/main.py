import base64
import json
import os

from google.cloud import pubsub_v1

publisher = pubsub_v1.PublisherClient()


def create_order(request):
    if request.content_type != "application/json":
        return {"status": "error", "message": "Content-Type must be application/json"}, 400
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return {"status": "error", "message": "Request body must be JSON object"}, 400
    item = payload.get("item")
    quantity = payload.get("quantity")
    if not isinstance(item, str) or not item.strip() or len(item.strip()) > 256:
        return {"status": "error", "message": "item must be a non-empty string up to 256 characters"}, 400
    if isinstance(quantity, bool) or not isinstance(quantity, int) or quantity <= 0:
        return {"status": "error", "message": "quantity must be a positive integer"}, 400
    topic = publisher.topic_path(os.environ["GOOGLE_CLOUD_PROJECT"], os.environ["ORDERS_TOPIC"])
    message_id = publisher.publish(topic, json.dumps({"item": item.strip(), "quantity": quantity}).encode()).result()
    return {"status": "queued", "messageId": message_id}, 202
