import json
import logging
import os
import uuid

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    batch_item_failures = []

    for record in event["Records"]:
        message_id = record["messageId"]
        try:
            order_id = str(uuid.uuid4())
            table.put_item(Item={"orderID": order_id, "order": record["body"]})
            logger.info(
                json.dumps(
                    {
                        "event": "order_persisted",
                        "messageId": message_id,
                        "orderID": order_id,
                    }
                )
            )
        except Exception:
            logger.exception(
                json.dumps(
                    {
                        "event": "order_persist_failed",
                        "messageId": message_id,
                    }
                )
            )
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}
