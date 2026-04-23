#!/bin/bash
set -e

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
INPUT_BUCKET="glue-video-input-${ACCOUNT_ID}"
FRAMES_BUCKET="glue-video-frames-${ACCOUNT_ID}"
OUTPUT_BUCKET="glue-video-output-${ACCOUNT_ID}"
ROLE_NAME="GlueVideoFrameExtractorRole"

echo "=== Cleaning up AWS Glue Video Processing Labs ==="

for JOB in video-frame-extractor video-frame-annotator video-frame-stitcher; do
  aws glue delete-job --job-name "$JOB" --region "$REGION" 2>/dev/null && echo "Deleted job: $JOB" || echo "Job not found: $JOB"
done

for BUCKET in "$INPUT_BUCKET" "$FRAMES_BUCKET" "$OUTPUT_BUCKET"; do
  aws s3 rb "s3://${BUCKET}" --force --region "$REGION" 2>/dev/null && echo "Deleted bucket: $BUCKET" || echo "Bucket not found: $BUCKET"
done

aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name GlueVideoS3Access 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null && echo "Deleted IAM role" || echo "IAM role not found"

echo "=== Cleanup Complete ==="
