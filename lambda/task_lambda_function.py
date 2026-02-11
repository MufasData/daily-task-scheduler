import json
import boto3
import os

sns = boto3.client('sns', region_name='us-east-2')

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event))
    
    # If it's a manual load to S3
    if 'Records' in event:
        for record in event['Records']:
            sns_message = json.loads(record['Sns']['Message'])
            for s3_record in sns_message['Records']:
                bucket_name = s3_record['s3']['bucket']['name']
                file_name = s3_record['s3']['object']['key']
                send_email(f"S3 UPLOAD ALERT\nFile: {file_name}\nBucket: {bucket_name}")
                
    # From Eventbridge
    elif event.get('source') == 'aws.events':
        send_email("⏰ AUTOMATED 2-MINUTE HEARTBEAT\nThe scheduler is running on standby.")

    return {'statusCode': 200}

def send_email(text):
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Message=text,
        Subject="🌅 Task Scheduler Update"
    )