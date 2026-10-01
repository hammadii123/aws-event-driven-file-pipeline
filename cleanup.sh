#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="file-pipeline-bucket-${ACCOUNT_ID}"
QUEUE_NAME="file-notification-queue"
TOPIC_NAME="file-notification-topic"
FUNCTION_NAME="FileNotifierLambda"
ROLE_NAME="LambdaLeastPrivilegeRole"

echo "Deleting Event Source Mapping..."
UUID=$(aws lambda list-event-source-mappings --function-name "${FUNCTION_NAME}" --query 'EventSourceMappings[0].UUID' --output text 2>/dev/null || true)
if [ -n "${UUID}" ] && [ "${UUID}" != "None" ]; then
    aws lambda delete-event-source-mapping --uuid "${UUID}"
fi

echo "Deleting Lambda Function..."
aws lambda delete-function --function-name "${FUNCTION_NAME}" || true

echo "Deleting IAM Role and Inline Policy..."
aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name LeastPrivilegePolicy || true
aws iam delete-role --role-name "${ROLE_NAME}" || true

echo "Deleting SQS Queue..."
QUEUE_URL=$(aws sqs get-queue-url --queue-name "${QUEUE_NAME}" --query QueueUrl --output text 2>/dev/null || true)
if [ -n "${QUEUE_URL}" ] && [ "${QUEUE_URL}" != "None" ]; then
    aws sqs delete-queue --queue-url "${QUEUE_URL}"
fi

echo "Deleting SNS Topic..."
TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, '${TOPIC_NAME}')].TopicArn" --output text 2>/dev/null || true)
if [ -n "${TOPIC_ARN}" ] && [ "${TOPIC_ARN}" != "None" ]; then
    aws sns delete-topic --topic-arn "${TOPIC_ARN}"
fi

echo "Purging and Deleting S3 Bucket..."
aws s3 rm "s3://${BUCKET_NAME}" --recursive 2>/dev/null || true
aws s3api delete-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null || true

echo "Teardown complete."
