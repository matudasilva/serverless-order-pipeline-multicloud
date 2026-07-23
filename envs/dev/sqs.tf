data "aws_caller_identity" "current" {}

resource "aws_sqs_queue" "poc_queue_dlq" {
  name = "POC-Queue-DLQ"
}

resource "aws_sqs_queue" "poc_queue" {
  name = "POC-Queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.poc_queue_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_policy" "poc_queue" {
  queue_url = aws_sqs_queue.poc_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = aws_sqs_queue.poc_queue.arn
      }
    ]
  })
}
