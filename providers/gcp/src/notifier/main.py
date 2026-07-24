import json
import os

from cloudevents.http import from_http
from google.cloud import pubsub_v1

publisher = pubsub_v1.PublisherClient()


def publish_notification(request):
    event = from_http(request.headers, request.get_data())
    subject = event["subject"]
    order_id = subject.rsplit("/", 1)[-1]
    topic = publisher.topic_path(os.environ["GOOGLE_CLOUD_PROJECT"], os.environ["NOTIFICATIONS_TOPIC"])
    publisher.publish(topic, json.dumps({"orderId": order_id, "eventId": event["id"]}).encode()).result()
    return "", 204
