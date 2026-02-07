output "s3_bucket_name" {
  value = aws_s3_bucket.task_bucket.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.task_notifications.arn
}
