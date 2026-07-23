locals {
  lambda_1_function_name = "POC-Lambda-1"
  lambda_2_function_name = "POC-Lambda-2"
}

resource "aws_cloudwatch_log_group" "lambda_1" {
  name              = "/aws/lambda/${local.lambda_1_function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "lambda_2" {
  name              = "/aws/lambda/${local.lambda_2_function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Lambda 1: consumes POC-Queue, writes to the orders table, own log group.
resource "aws_iam_role" "lambda_1" {
  name               = "poc-lambda-1-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_1" {
  statement {
    sid    = "ConsumePocQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [aws_sqs_queue.poc_queue.arn]
  }

  statement {
    sid       = "WriteOrders"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }

  statement {
    sid    = "WriteOwnLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda_1.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda_1" {
  name   = "poc-lambda-1-policy"
  role   = aws_iam_role.lambda_1.id
  policy = data.aws_iam_policy_document.lambda_1.json
}

# Lambda 2: reads the orders table's stream, publishes to POC-Topic, own log group.
resource "aws_iam_role" "lambda_2" {
  name               = "poc-lambda-2-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_2" {
  statement {
    sid    = "ReadOrdersStream"
    effect = "Allow"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams",
    ]
    # dynamodb:ListStreams cannot be scoped to a single stream ARN — the
    # stream/* pattern is the finest granularity IAM supports, since the
    # exact stream ARN doesn't exist until the table is created (ADR-2).
    resources = ["${aws_dynamodb_table.orders.arn}/stream/*"]
  }

  statement {
    sid       = "PublishOrderNotifications"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.orders_notifications.arn]
  }

  statement {
    sid    = "WriteOwnLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda_2.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda_2" {
  name   = "poc-lambda-2-policy"
  role   = aws_iam_role.lambda_2.id
  policy = data.aws_iam_policy_document.lambda_2.json
}
