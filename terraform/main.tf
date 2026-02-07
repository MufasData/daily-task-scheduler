provider "aws" {
  region = "us-east-2"
}

# Main Task Manager Bucket where daily task files are placed
resource "aws_s3_bucket" "task_bucket" {
  bucket = "mufas-task-manager-${random_id.id.hex}"
  }

# Topic where tasks will be sent to from s3
resource "aws_sns_topic" "task_notifications" {
  name = "daily-tasks"
  }

# Email subscription where tasks will be sent to from SNS
resource "aws_sns_topic_subscription" "my_email_subscription" {
  topic_arn = aws_sns_topic.task_notifications.arn
  protocol = "email"
  endpoint = "asaahndangoh@outlook.com"
  }

#For making the S3 bucket unique
resource "random_id" "id" {
  byte_length = 4
}