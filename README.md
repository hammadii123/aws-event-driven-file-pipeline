# AWS Event-Driven File Notification Pipeline

An asynchronous, serverless notification system deployed entirely via the AWS CLI. This architecture decouples object ingestion from processing by queuing events through Amazon SQS before triggering AWS Lambda to inspect metadata and dispatch email notifications via Amazon SNS.

## Architecture Flow

1. Upload: An object is placed into Amazon S3.
2. Event Dispatch: A JSON notification is published to Amazon SQS containing the bucket name and object key.
3. Compute & Extraction: AWS Lambda consumes the queue message via Event Source Mapping, queries Amazon S3 for object headers using the HeadObject API, and extracts file metadata.
4. Notification: Metadata attributes (size, content type, last modified, ETag, storage class) are published to an Amazon SNS topic.
5. Delivery: Amazon SNS delivers an alert email to subscribed endpoints.
6. Observability: Function invocations, payloads, and execution traces are recorded in Amazon CloudWatch Logs.

## Least-Privilege IAM Policy

The execution role strictly avoids wildcard (*) permissions:
- Amazon S3: `s3:GetObject` constrained to the target bucket ARN.
- Amazon SQS: `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and `sqs:GetQueueAttributes` constrained to the target queue ARN.
- Amazon SNS: `sns:Publish` constrained to the target topic ARN.
- Amazon CloudWatch: `logs:CreateLogGroup`, `logs:CreateLogStream`, and `logs:PutLogEvents` constrained to the specific Lambda log group path.

## Deployment

1. Ensure the AWS CLI is configured with valid credentials.
2. Make scripts executable:
   chmod +x build.sh cleanup.sh
3. Execute the provisioning script:
   ./build.sh

## Teardown

To delete all provisioned cloud infrastructure and prevent costs:
./cleanup.sh
