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
  topic_arn = aws_sns_topic.formatted_alerts.arn    # Updated this. This is the new topic to decouple the topics 
  protocol = "email"
  endpoint = "asaahndangoh@outlook.com"
  }

#For making the S3 bucket unique
resource "random_id" "id" {
  byte_length = 4
}

# Notification to SNS when json file uploaded
resource "aws_s3_bucket_notification" "bucket_notification" {
    bucket = aws_s3_bucket.task_bucket.id

    topic {
        topic_arn = aws_sns_topic.task_notifications.arn
        events = ["s3:ObjectCreated:*"]
        filter_suffix = ".json"
    }
}

# Policy to allow S3 bucket publish to the SNS topic
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.task_notifications.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.task_bucket.arn]
    }
  }
}

# 2. Attach the created olicy to the SNS topic
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.task_notifications.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

# Zipping the Lambda code from the local Python script (Terraform requires a zip to upload)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir = "../lambda"
  output_path = "task_lambda_function.zip"
}

# Creating an IAM Role for Lambda
resource "aws_iam_role" "iam_for_lambda" {
  name = "task_scheduler_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Create the Lambda Function in AWS
resource "aws_lambda_function" "task_processor" {
  filename         = "task_lambda_function.zip"
  function_name    = "daily-task-processor"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "task_lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.formatted_alerts.arn
    }
  }
}

# The two below allow SNS to trigger the lambda
resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.task_notifications.arn
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.task_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.task_processor.arn
}

# This gives the Lambda "Robot" the right to send SNS messages
resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "lambda_sns_publish_policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# The NEW topic for the formatted emails as they keep coming up in raw format
resource "aws_sns_topic" "formatted_alerts" {
  name = "formatted-task-alerts"
}

# # Trigger Set to fire every 2 minutes (for testing)
# resource "aws_cloudwatch_event_rule" "every_two_minutes" {
#   name                = "every-two-minutes"
#   description         = "Triggers the task scheduler every 2 minutes for rapid testing"
#   schedule_expression = "rate(2 minutes)" # Changed from 10 to 2
# }

resource "aws_cloudwatch_event_rule" "weekly_monday_7am" {
  name                = "weekly-monday-7am-trigger"
  description         = "Triggers the task scheduler every Monday at 7:00 AM"
  
  # Format: cron(Minutes Hours Day-of-month Month Day-of-week Year)
  # 0 7 ? * MON * is 0 minutes, 7th hour, any day of month, every month, on MONDAYS.
  schedule_expression = "cron(0 7 ? * MON *)"
}

# Rule point to Lambda to be triggered
resource "aws_cloudwatch_event_target" "trigger_lambda_on_rate" {
  rule      = aws_cloudwatch_event_rule.weekly_monday_7am.name
  target_id = "task_processor"
  arn       = aws_lambda_function.task_processor.arn
}

# The permission to Allow EventBridge to trigger your Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_monday_7am.arn
}