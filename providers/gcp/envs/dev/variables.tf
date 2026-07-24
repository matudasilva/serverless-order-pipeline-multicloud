variable "project_id" { type = string }
variable "project_number" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "billing_budget_amount" {
  type    = number
  default = 5
}
variable "ingress_image" { type = string }
variable "processor_image" { type = string }
variable "notifier_image" { type = string }
