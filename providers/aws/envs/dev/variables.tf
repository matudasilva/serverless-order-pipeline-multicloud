variable "notification_email" {
  description = "Email address subscribed to the SNS topic that receives order notifications."
  type        = string
  sensitive   = true
}
