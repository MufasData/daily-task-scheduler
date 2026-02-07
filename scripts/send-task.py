import boto3

sns_client = boto3.client('sns', region_name='us-east-2')

SNS_TOPIC_ARN = "arn:aws:sns:us-east-2:172670236523:daily-tasks"

def send_task_notification(task_name, details):
    message = f"NEW TASK ASSIGNED:\n\nTask: {task_name}\nDetails: {details}"

    try:
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=message,
            Subject='Daily Task Alert'
        )
        print(f"Notification Sent! MEssage ID: {response['MessageId']}")
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    send_task_notification(
        "Complete AWS Project 1",
        "Implement Boto3 script and push code to GitHub."
    )