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
./run.sh extract sample     # Lab 1: video → frames
./run.sh annotate sample    # Lab 2: detect & annotate
./run.sh stitch sample      # Lab 3: frames → video
./run.sh all sample         # Run all 3 in sequence
./run.sh status             # Check job status
```

Available videos: `sample`, `batminton`, `cloud`, `dna`, `flyover`, `tunneltraffic`

## Hands-On Tutorial

See **[TUTORIAL.md](TUTORIAL.md)** for the full 3-lab training:

| Lab | Description | Glue Job |
|-----|-------------|----------|
| Lab 1 | Video → Frames (extract) | `video-frame-extractor` |
| Lab 2 | Feature extraction & annotation (detect balls) | `video-frame-annotator` |
| Lab 3 | Annotated frames → Video (stitch) | `video-frame-stitcher` |

## Cleanup

```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Files

| File | Description |
|------|-------------|
| `run.sh` | Helper script to run labs easily |
| `setup.sh` | One-click setup: creates buckets, IAM role, uploads deps, creates Glue jobs |
| `cleanup.sh` | Tears down all created AWS resources |
| `extract_frames.py` | Lab 1 — extracts video frames using OpenCV |
| `annotate_frames.py` | Lab 2 — detects balls and draws bounding boxes |
| `stitch_video.py` | Lab 3 — stitches annotated frames back into video |
| `TUTORIAL.md` | Step-by-step hands-on tutorial |
| `sample-video/sample.mp4` | Default test video |
| `sample-video/batminton.mp4` | Badminton clip — shuttle detection |
| `sample-video/cloud.mp4` | Cloud footage |
| `sample-video/dna.mp4` | DNA animation |
| `sample-video/flyover.mp4` | Aerial flyover |
| `sample-video/tunneltraffic.mp4` | Tunnel traffic footage |
