# Baseline: original exercise code

> Record of the starting point as provided in the "Building a Proof of
> Concept for a Serverless Solution" exercise (AWS Architecting Solutions),
> AWS console, Python 3.9. This code is NOT deployed as-is: it's the
> reference on top of which the `core-pipeline` feature builds the
> improvements described in `specs/features/core-pipeline/plan.md` (error
> handling, structured logging, configuration via environment variables,
> boto3 clients outside the handler, least-privilege IAM).

## Lambda 1 — POC-Lambda-1 (SQS → DynamoDB)

```python
import boto3, uuid

client = boto3.resource('dynamodb')
table = client.Table("orders")

def lambda_handler(event, context):
    for record in event['Records']:
        print("test")
        payload = record["body"]
        print(str(payload))
        table.put_item(Item={'orderID': str(uuid.uuid4()), 'order': payload})
```

## Lambda 2 — POC-Lambda-2 (DynamoDB Streams → SNS)

```python
import boto3, json

client = boto3.client('sns')

def lambda_handler(event, context):
    for record in event["Records"]:
        if record['eventName'] == 'INSERT':
            new_record = record['dynamodb']['NewImage']
            response = client.publish(
                TargetArn='<SNS topic ARN, hardcoded in the original>',
                Message=json.dumps({'default': json.dumps(new_record)}),
                MessageStructure='json'
            )
```

## Original architecture

```
Client → API Gateway (POST) → SQS → Lambda 1 → DynamoDB (orders)
                                                      │
                                                      ▼ (Streams, NEW_IMAGE)
                                                  Lambda 2 → SNS → Email
```

Region: us-east-1. Original runtime: Python 3.9 (upgraded to 3.12 in this
implementation).
