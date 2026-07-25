import base64
import json
import os
import uuid

from google.cloud import firestore

db = firestore.Client()


def process_order(request):
    envelope = request.get_json(silent=True) or {}
    message = envelope.get("message") or {}
    try:
        payload = json.loads(base64.b64decode(message["data"]).decode())
        message_id = message["messageId"]
    except (KeyError, ValueError, UnicodeDecodeError) as exc:
        return {"error": f"invalid Pub/Sub envelope: {exc}"}, 400
    order_id = str(uuid.uuid4())
    db.collection(os.environ.get("ORDERS_COLLECTION", "orders")).document(order_id).create(
        {"orderId": order_id, "messageId": message_id, "order": payload}
    )
    return "", 204
