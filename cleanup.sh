#!/bin/bash
set -e

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
INPUT_BUCKET="glue-video-input-${ACCOUNT_ID}"
OUTPUT_BUCKET="glue-video-frames-${ACCOUNT_ID}"
ROLE_NAME="GlueVideoFrameExtractorRole"
JOB_NAME="video-frame-extractor"

echo "=== Cleaning up AWS Glue Video Frame Extractor ==="

aws glue delete-job --job-name "$JOB_NAME" --region "$REGION" 2>/dev/null && echo "Deleted Glue job" || echo "Glue job not found"
aws s3 rb "s3://${INPUT_BUCKET}" --force --region "$REGION" 2>/dev/null && echo "Deleted input bucket" || echo "Input bucket not found"
aws s3 rb "s3://${OUTPUT_BUCKET}" --force --region "$REGION" 2>/dev/null && echo "Deleted output bucket" || echo "Output bucket not found"
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name GlueVideoS3Access 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null && echo "Deleted IAM role" || echo "IAM role not found"

echo "=== Cleanup Complete ==="
