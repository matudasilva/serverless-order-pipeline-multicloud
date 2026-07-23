data "archive_file" "lambda_1" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambdas/lambda_1"
  output_path = "${path.module}/.build/lambda_1.zip"
}

data "archive_file" "lambda_2" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/lambdas/lambda_2"
  output_path = "${path.module}/.build/lambda_2.zip"
}

resource "aws_lambda_function" "lambda_1" {
  function_name    = local.lambda_1_function_name
  role             = aws_iam_role.lambda_1.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_1.output_path
  source_code_hash = data.archive_file.lambda_1.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.orders.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_1]
}

resource "aws_lambda_function" "lambda_2" {
  function_name    = local.lambda_2_function_name
  role             = aws_iam_role.lambda_2.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_2.output_path
  source_code_hash = data.archive_file.lambda_2.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.orders_notifications.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_2]
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda_1" {
  event_source_arn = aws_sqs_queue.poc_queue.arn
  function_name    = aws_lambda_function.lambda_1.arn
  batch_size       = 10

  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_event_source_mapping" "stream_to_lambda_2" {
  event_source_arn  = aws_dynamodb_table.orders.stream_arn
  function_name     = aws_lambda_function.lambda_2.arn
  starting_position = "LATEST"
  batch_size        = 100
}
