#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="file-pipeline-bucket-${ACCOUNT_ID}"
QUEUE_NAME="file-notification-queue"
TOPIC_NAME="file-notification-topic"
FUNCTION_NAME="FileNotifierLambda"
ROLE_NAME="LambdaLeastPrivilegeRole"
EMAIL_ENDPOINT="your-email@example.com"

echo "Provisioning Amazon S3 Bucket..."
aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"

echo "Provisioning Amazon SQS Queue..."
aws sqs create-queue --queue-name "${QUEUE_NAME}"
QUEUE_URL=$(aws sqs get-queue-url --queue-name "${QUEUE_NAME}" --query QueueUrl --output text)
QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url "${QUEUE_URL}" --attribute-names QueueArn --query Attributes.QueueArn --output text)

echo "Provisioning Amazon SNS Topic..."
TOPIC_ARN=$(aws sns create-topic --name "${TOPIC_NAME}" --query TopicArn --output text)
aws sns subscribe --topic-arn "${TOPIC_ARN}" --protocol email --notification-endpoint "${EMAIL_ENDPOINT}"

echo "Creating IAM Role and Attaching Least Privilege Policy..."
aws iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document file://lambda-trust-policy.json

sed -e "s|<BUCKET_NAME>|${BUCKET_NAME}|g" \
    -e "s|<QUEUE_ARN>|${QUEUE_ARN}|g" \
    -e "s|<TOPIC_ARN>|${TOPIC_ARN}|g" \
    -e "s|<REGION>|${REGION}|g" \
    -e "s|<ACCOUNT_ID>|${ACCOUNT_ID}|g" \
    iam-permissions-policy.json > rendered-policy.json

aws iam put-role-policy --role-name "${ROLE_NAME}" --policy-name LeastPrivilegePolicy --policy-document file://rendered-policy.json
rm -f rendered-policy.json

sleep 10

echo "Deploying AWS Lambda Function..."
zip function.zip lambda_function.py
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

aws lambda create-function \
    --function-name "${FUNCTION_NAME}" \
    --runtime python3.11 \
    --role "${ROLE_ARN}" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{TOPIC_ARN=${TOPIC_ARN}}" \
    --timeout 15

rm -f function.zip

echo "Configuring Event Source Mapping..."
aws lambda create-event-source-mapping \
    --function-name "${FUNCTION_NAME}" \
    --batch-size 1 \
    --event-source-arn "${QUEUE_ARN}"

echo "Deployment complete."
