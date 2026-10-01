import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
sns = boto3.client('sns')
TOPIC_ARN = os.environ.get('TOPIC_ARN')

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            body = json.loads(record['body'])
            bucket = body['bucket']
            key = body['key']

            logger.info(f"Processing object {key} from bucket {bucket}")

            response = s3.head_object(Bucket=bucket, Key=key)

            size = response.get('ContentLength', 0)
            content_type = response.get('ContentType', 'Unknown')
            last_modified = str(response.get('LastModified', 'Unknown'))
            etag = response.get('ETag', '').replace('"', '')
            storage_class = response.get('StorageClass', 'STANDARD')

            message = (
                f"S3 File Ingestion Notification\n\n"
                f"File Name: {key}\n"
                f"Bucket: {bucket}\n"
                f"Size: {size} bytes\n"
                f"Content Type: {content_type}\n"
                f"Last Modified: {last_modified}\n"
                f"ETag: {etag}\n"
                f"Storage Class: {storage_class}\n"
            )

            sns.publish(
                TopicArn=TOPIC_ARN,
                Subject=f"S3 File Alert: {key}",
                Message=message
            )
            logger.info(f"Notification published successfully for {key}")

        return {"statusCode": 200, "body": json.dumps("Processing complete")}

    except Exception as exc:
        logger.error(f"Error processing record: {str(exc)}")
        raise exc
