#!/bin/bash
set -e

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
INPUT_BUCKET="glue-video-input-${ACCOUNT_ID}"
OUTPUT_BUCKET="glue-video-frames-${ACCOUNT_ID}"
ROLE_NAME="GlueVideoFrameExtractorRole"
JOB_NAME="video-frame-extractor"

echo "=== AWS Glue Video Frame Extractor Setup ==="
echo "Region:  $REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# Create S3 buckets
echo "Creating S3 buckets..."
aws s3api create-bucket --bucket "$INPUT_BUCKET" \
  --create-bucket-configuration LocationConstraint="$REGION" --region "$REGION" 2>/dev/null || echo "  Input bucket already exists"
aws s3api create-bucket --bucket "$OUTPUT_BUCKET" \
  --create-bucket-configuration LocationConstraint="$REGION" --region "$REGION" 2>/dev/null || echo "  Output bucket already exists"

# Create IAM role
echo "Creating IAM role..."
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"glue.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --description "Role for Glue video frame extraction job" 2>/dev/null || echo "  Role already exists"

# Attach policy
echo "Attaching IAM policy..."
POLICY=$(cat <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],"Resource":["arn:aws:s3:::${INPUT_BUCKET}","arn:aws:s3:::${INPUT_BUCKET}/*"]},
    {"Effect":"Allow","Action":["s3:PutObject","s3:ListBucket"],"Resource":["arn:aws:s3:::${OUTPUT_BUCKET}","arn:aws:s3:::${OUTPUT_BUCKET}/*"]},
    {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:${REGION}:${ACCOUNT_ID}:*"}
  ]
}
EOF
)
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name GlueVideoS3Access --policy-document "$POLICY"

# Upload dependencies
echo "Downloading and uploading OpenCV + numpy wheels..."
pip download opencv-python-headless -d /tmp/cv2wheel --only-binary=:all: --platform manylinux2014_x86_64 --python-version 39 --no-deps -q 2>/dev/null
pip download numpy -d /tmp/cv2wheel --only-binary=:all: --platform manylinux2014_x86_64 --python-version 39 --no-deps -q 2>/dev/null
OPENCV_WHL=$(ls /tmp/cv2wheel/opencv_python_headless-*.whl | head -1)
NUMPY_WHL=$(ls /tmp/cv2wheel/numpy-*.whl | head -1)
aws s3 cp "$OPENCV_WHL" "s3://${INPUT_BUCKET}/libs/$(basename $OPENCV_WHL)" --region "$REGION" --quiet
aws s3 cp "$NUMPY_WHL" "s3://${INPUT_BUCKET}/libs/$(basename $NUMPY_WHL)" --region "$REGION" --quiet

# Upload script
echo "Uploading Glue script..."
aws s3 cp extract_frames.py "s3://${INPUT_BUCKET}/scripts/extract_frames.py" --region "$REGION" --quiet

# Upload sample video
echo "Uploading sample video..."
aws s3 cp sample-video/sample.mp4 "s3://${INPUT_BUCKET}/videos/sample.mp4" --region "$REGION" --quiet

# Wait for IAM propagation
echo "Waiting 10s for IAM role propagation..."
sleep 10

# Create Glue job
echo "Creating Glue job..."
EXTRA_PY="s3://${INPUT_BUCKET}/libs/$(basename $OPENCV_WHL),s3://${INPUT_BUCKET}/libs/$(basename $NUMPY_WHL)"
aws glue create-job --name "$JOB_NAME" \
  --role "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
  --command "{\"Name\":\"pythonshell\",\"PythonVersion\":\"3.9\",\"ScriptLocation\":\"s3://${INPUT_BUCKET}/scripts/extract_frames.py\"}" \
  --default-arguments "{\"--INPUT_BUCKET\":\"${INPUT_BUCKET}\",\"--INPUT_KEY\":\"videos/sample.mp4\",\"--OUTPUT_BUCKET\":\"${OUTPUT_BUCKET}\",\"--extra-py-files\":\"${EXTRA_PY}\"}" \
  --glue-version "3.0" --max-capacity 0.0625 --region "$REGION" 2>/dev/null || echo "  Job already exists"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Run the job:"
echo "  aws glue start-job-run --job-name $JOB_NAME --region $REGION"
echo ""
echo "Check status:"
echo "  aws glue get-job-runs --job-name $JOB_NAME --region $REGION --query 'JobRuns[0].JobRunState'"
echo ""
echo "View output frames:"
echo "  aws s3 ls s3://${OUTPUT_BUCKET}/sample/ --region $REGION"
