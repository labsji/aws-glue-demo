#!/bin/bash
set -e

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
INPUT_BUCKET="glue-video-input-${ACCOUNT_ID}"
FRAMES_BUCKET="glue-video-frames-${ACCOUNT_ID}"
OUTPUT_BUCKET="glue-video-output-${ACCOUNT_ID}"
ROLE_NAME="GlueVideoFrameExtractorRole"

echo "=== AWS Glue Video Processing Lab Setup ==="
echo "Region:  $REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# Create S3 buckets
echo "Creating S3 buckets..."
for BUCKET in "$INPUT_BUCKET" "$FRAMES_BUCKET" "$OUTPUT_BUCKET"; do
  aws s3api create-bucket --bucket "$BUCKET" \
    --create-bucket-configuration LocationConstraint="$REGION" --region "$REGION" 2>/dev/null \
    && echo "  Created $BUCKET" || echo "  $BUCKET already exists"
done

# Create IAM role
echo "Creating IAM role..."
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"glue.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --description "Role for Glue video processing labs" 2>/dev/null || echo "  Role already exists"

# Attach policy
echo "Attaching IAM policy..."
POLICY=$(cat <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],"Resource":["arn:aws:s3:::${INPUT_BUCKET}","arn:aws:s3:::${INPUT_BUCKET}/*"]},
    {"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:ListBucket"],"Resource":["arn:aws:s3:::${FRAMES_BUCKET}","arn:aws:s3:::${FRAMES_BUCKET}/*"]},
    {"Effect":"Allow","Action":["s3:PutObject","s3:ListBucket"],"Resource":["arn:aws:s3:::${OUTPUT_BUCKET}","arn:aws:s3:::${OUTPUT_BUCKET}/*"]},
    {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:${REGION}:${ACCOUNT_ID}:*"}
  ]
}
EOF
)
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name GlueVideoS3Access --policy-document "$POLICY"

# Upload dependencies
echo "Downloading and uploading OpenCV + numpy wheels..."
mkdir -p /tmp/cv2wheel
pip download opencv-python-headless -d /tmp/cv2wheel --only-binary=:all: --platform manylinux2014_x86_64 --python-version 39 --no-deps -q 2>/dev/null
pip download numpy -d /tmp/cv2wheel --only-binary=:all: --platform manylinux2014_x86_64 --python-version 39 --no-deps -q 2>/dev/null
OPENCV_WHL=$(ls /tmp/cv2wheel/opencv_python_headless-*.whl | head -1)
NUMPY_WHL=$(ls /tmp/cv2wheel/numpy-*.whl | head -1)
aws s3 cp "$OPENCV_WHL" "s3://${INPUT_BUCKET}/libs/$(basename $OPENCV_WHL)" --region "$REGION" --quiet
aws s3 cp "$NUMPY_WHL" "s3://${INPUT_BUCKET}/libs/$(basename $NUMPY_WHL)" --region "$REGION" --quiet
EXTRA_PY="s3://${INPUT_BUCKET}/libs/$(basename $OPENCV_WHL),s3://${INPUT_BUCKET}/libs/$(basename $NUMPY_WHL)"

# Upload scripts
echo "Uploading Glue scripts..."
aws s3 cp extract_frames.py "s3://${INPUT_BUCKET}/scripts/extract_frames.py" --region "$REGION" --quiet
aws s3 cp annotate_frames.py "s3://${INPUT_BUCKET}/scripts/annotate_frames.py" --region "$REGION" --quiet
aws s3 cp stitch_video.py "s3://${INPUT_BUCKET}/scripts/stitch_video.py" --region "$REGION" --quiet

# Upload sample videos
echo "Uploading sample videos..."
for VIDEO in sample-video/*.mp4; do
  aws s3 cp "$VIDEO" "s3://${INPUT_BUCKET}/videos/$(basename $VIDEO)" --region "$REGION" --quiet
done

# Wait for IAM propagation
echo "Waiting 10s for IAM role propagation..."
sleep 10

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Lab 1: Extract frames
echo "Creating Glue job: video-frame-extractor..."
aws glue create-job --name "video-frame-extractor" \
  --role "$ROLE_ARN" \
  --command "{\"Name\":\"pythonshell\",\"PythonVersion\":\"3.9\",\"ScriptLocation\":\"s3://${INPUT_BUCKET}/scripts/extract_frames.py\"}" \
  --default-arguments "{\"--INPUT_BUCKET\":\"${INPUT_BUCKET}\",\"--INPUT_KEY\":\"videos/sample.mp4\",\"--OUTPUT_BUCKET\":\"${FRAMES_BUCKET}\",\"--extra-py-files\":\"${EXTRA_PY}\"}" \
  --glue-version "3.0" --max-capacity 0.0625 --region "$REGION" 2>/dev/null || echo "  Job already exists"

# Lab 2: Annotate frames
echo "Creating Glue job: video-frame-annotator..."
aws glue create-job --name "video-frame-annotator" \
  --role "$ROLE_ARN" \
  --command "{\"Name\":\"pythonshell\",\"PythonVersion\":\"3.9\",\"ScriptLocation\":\"s3://${INPUT_BUCKET}/scripts/annotate_frames.py\"}" \
  --default-arguments "{\"--FRAMES_BUCKET\":\"${FRAMES_BUCKET}\",\"--FRAMES_PREFIX\":\"sample\",\"--OUTPUT_BUCKET\":\"${FRAMES_BUCKET}\",\"--extra-py-files\":\"${EXTRA_PY}\"}" \
  --glue-version "3.0" --max-capacity 0.0625 --region "$REGION" 2>/dev/null || echo "  Job already exists"

# Lab 3: Stitch video
echo "Creating Glue job: video-frame-stitcher..."
aws glue create-job --name "video-frame-stitcher" \
  --role "$ROLE_ARN" \
  --command "{\"Name\":\"pythonshell\",\"PythonVersion\":\"3.9\",\"ScriptLocation\":\"s3://${INPUT_BUCKET}/scripts/stitch_video.py\"}" \
  --default-arguments "{\"--FRAMES_BUCKET\":\"${FRAMES_BUCKET}\",\"--FRAMES_PREFIX\":\"sample-annotated\",\"--OUTPUT_BUCKET\":\"${OUTPUT_BUCKET}\",\"--OUTPUT_KEY\":\"sample-annotated.mp4\",\"--FPS\":\"1\",\"--extra-py-files\":\"${EXTRA_PY}\"}" \
  --glue-version "3.0" --max-capacity 0.0625 --region "$REGION" 2>/dev/null || echo "  Job already exists"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Three Glue jobs created. Follow the tutorial in TUTORIAL.md"
echo ""
echo "Quick test — run all 3 labs in sequence:"
echo "  aws glue start-job-run --job-name video-frame-extractor --region $REGION"
echo "  # wait for completion, then:"
echo "  aws glue start-job-run --job-name video-frame-annotator --region $REGION"
echo "  # wait for completion, then:"
echo "  aws glue start-job-run --job-name video-frame-stitcher --region $REGION"
