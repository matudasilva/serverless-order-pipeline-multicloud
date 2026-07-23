output "poc_queue_url" {
  description = "URL of the POC-Queue SQS queue."
  value       = aws_sqs_queue.poc_queue.id
}

output "poc_queue_arn" {
  description = "ARN of the POC-Queue SQS queue."
  value       = aws_sqs_queue.poc_queue.arn
}

output "orders_table_name" {
  description = "Name of the orders DynamoDB table."
  value       = aws_dynamodb_table.orders.name
}

output "orders_notifications_topic_arn" {
  description = "ARN of the POC-Topic SNS topic."
  value       = aws_sns_topic.orders_notifications.arn
}

output "api_invoke_url" {
  description = "Invoke URL of the dev stage of POC-API (append /orders to POST an order)."
  value       = aws_api_gateway_stage.dev.invoke_url
}
