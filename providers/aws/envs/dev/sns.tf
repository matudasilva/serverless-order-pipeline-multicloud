resource "aws_sns_topic" "orders_notifications" {
  name = "POC-Topic"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.orders_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
