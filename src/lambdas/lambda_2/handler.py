import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns = boto3.client("sns")
topic_arn = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    for record in event["Records"]:
        if record["eventName"] != "INSERT":
            continue

        new_image = record["dynamodb"]["NewImage"]
        sequence_number = record["dynamodb"]["SequenceNumber"]

        try:
            sns.publish(
                TopicArn=topic_arn,
                Message=json.dumps({"default": json.dumps(new_image)}),
                MessageStructure="json",
            )
            logger.info(
                json.dumps(
                    {
                        "event": "order_notification_published",
                        "sequenceNumber": sequence_number,
                    }
                )
            )
        except Exception:
            logger.exception(
                json.dumps(
                    {
                        "event": "order_notification_failed",
                        "sequenceNumber": sequence_number,
                    }
                )
            )
            raise
