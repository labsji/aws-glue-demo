# AWS Glue Video Frame Extractor

An AWS Glue Python shell job that extracts JPG frames from a video stored in S3 and writes them to an output S3 bucket.

## Architecture

```
S3 (input video) → AWS Glue Python Shell Job → S3 (JPG frames)
```

- Extracts 1 frame per second using OpenCV
- Uses minimal 1/16 DPU Python shell job
- Includes IAM role with least-privilege access

## Quick Start (AWS CloudShell)

```bash
git clone https://github.com/labsji/aws-glue-demo.git
cd aws-glue-demo
chmod +x setup.sh
./setup.sh
```

By default this uses `ap-south-1` (Mumbai). Override with:

```bash
AWS_REGION=us-east-1 ./setup.sh
```

## Run the Job

```bash
aws glue start-job-run --job-name video-frame-extractor --region ap-south-1
```

Check status:

```bash
aws glue get-job-runs --job-name video-frame-extractor --region ap-south-1 --query 'JobRuns[0].JobRunState'
```

View output:

```bash
aws s3 ls s3://glue-video-frames-<ACCOUNT_ID>/sample/
```

## Use Your Own Video

```bash
aws s3 cp my-video.mp4 s3://glue-video-input-<ACCOUNT_ID>/videos/my-video.mp4 --region ap-south-1
aws glue start-job-run --job-name video-frame-extractor \
  --arguments '{"--INPUT_KEY":"videos/my-video.mp4"}' --region ap-south-1
```

## Cleanup

```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Files

| File | Description |
|------|-------------|
| `setup.sh` | One-click setup: creates buckets, IAM role, uploads deps, creates Glue job |
| `cleanup.sh` | Tears down all created AWS resources |
| `extract_frames.py` | Glue job script — extracts video frames using OpenCV |
| `sample-video/sample.mp4` | Sample test video |
