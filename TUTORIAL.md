# AWS Glue Video Processing — Hands-On Tutorial

This tutorial walks you through a complete video processing pipeline using AWS Glue Python shell jobs.

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  S3: Input   │────▶│  Lab 1: Extract  │────▶│  Lab 2: Annotate │────▶│  Lab 3: Stitch   │
│  (video)     │     │  (video→frames)  │     │  (detect balls)  │     │  (frames→video)  │
└─────────────┘     └──────────────────┘     └──────────────────┘     └──────────────────┘
                            │                        │                        │
                            ▼                        ▼                        ▼
                     S3: frames bucket         S3: frames bucket        S3: output bucket
                     sample/frame_*.jpg        sample-annotated/       sample-annotated.mp4
```

## Prerequisites

- AWS CloudShell (or any environment with AWS CLI configured)
- An AWS account with permissions to create S3 buckets, IAM roles, and Glue jobs

## Setup

```bash
git clone https://github.com/labsji/aws-glue-demo.git
cd aws-glue-demo
chmod +x setup.sh cleanup.sh
./setup.sh
```

This creates:
- 3 S3 buckets: `glue-video-input-<ACCOUNT>`, `glue-video-frames-<ACCOUNT>`, `glue-video-output-<ACCOUNT>`
- 1 IAM role with least-privilege S3 + CloudWatch access
- 3 Glue Python shell jobs (one per lab)

---

## Lab 1: Video → Frames (Extract)

**Goal:** Extract JPG frames from a video stored in S3 using AWS Glue.

**What it does:** Downloads the video from S3, uses OpenCV to extract 1 frame per second, and uploads each frame as a JPG to the frames bucket.

### Run

```bash
REGION=ap-south-1  # or your chosen region

aws glue start-job-run --job-name video-frame-extractor --region $REGION
```

### Monitor

```bash
aws glue get-job-runs --job-name video-frame-extractor --region $REGION \
  --query 'JobRuns[0].{State:JobRunState,Duration:ExecutionTime}'
```

### Verify

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 ls s3://glue-video-frames-${ACCOUNT_ID}/sample/
```

You should see `frame_00000.jpg`, `frame_00001.jpg`, etc.

### Key Code (`extract_frames.py`)

```python
cap = cv2.VideoCapture(tmp_path)
fps = cap.get(cv2.CAP_PROP_FPS)
interval = int(fps)  # 1 frame per second

while cap.isOpened():
    ret, frame = cap.read()
    if frame_num % interval == 0:
        _, buf = cv2.imencode('.jpg', frame)
        s3.put_object(Bucket=output_bucket, Key=key, Body=buf.tobytes())
```

### Try with other videos

```bash
aws s3 cp sample-video/soccer.mp4 s3://glue-video-input-${ACCOUNT_ID}/videos/soccer.mp4 --region $REGION
aws glue start-job-run --job-name video-frame-extractor \
  --arguments '{"--INPUT_KEY":"videos/soccer.mp4"}' --region $REGION
```

Available: `soccer.mp4`, `tennis.mp4`, `basketball.mp4`, `cricket.mp4`

---

## Lab 2: Feature Extraction & Annotation (Detect)

**Goal:** Run a simple ball detection algorithm on each frame and draw bounding boxes.

**What it does:** Reads each frame from S3, applies HSV color filtering + contour detection to find ball-like objects, draws green bounding boxes, and saves annotated frames.

### Run

```bash
aws glue start-job-run --job-name video-frame-annotator --region $REGION
```

### Verify

```bash
aws s3 ls s3://glue-video-frames-${ACCOUNT_ID}/sample-annotated/
```

### Key Code (`annotate_frames.py`)

The detection uses a two-pass color filter:

```python
# Pass 1: White/bright objects (cricket ball, soccer ball)
lower = np.array([0, 0, 200])
upper = np.array([180, 60, 255])
mask = cv2.inRange(hsv, lower, upper)

# Pass 2: Orange/yellow objects (basketball, tennis ball)
lower2 = np.array([10, 100, 100])
upper2 = np.array([30, 255, 255])
mask2 = cv2.inRange(hsv, lower2, upper2)

# Combine and find circular contours
contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
```

### 🎯 Student Exercise

The provided detection is basic. Try improving it:

1. **Tune the HSV ranges** — adjust `lower`/`upper` values for your specific sport
2. **Add more color ranges** — red for a cricket ball, green for a tennis ball on clay
3. **Use morphological operations** — add `cv2.erode()` / `cv2.dilate()` to clean up the mask
4. **Try edge detection** — use `cv2.HoughCircles()` for better circular object detection
5. **Add tracking** — compare ball position across frames to filter false positives

Edit `annotate_frames.py`, re-upload, and re-run:

```bash
aws s3 cp annotate_frames.py s3://glue-video-input-${ACCOUNT_ID}/scripts/annotate_frames.py --region $REGION
aws glue start-job-run --job-name video-frame-annotator --region $REGION
```

---

## Lab 3: Annotated Frames → Video (Stitch)

**Goal:** Stitch the annotated frames back into an MP4 video using AWS Glue.

**What it does:** Reads all annotated JPG frames from S3 in order, uses OpenCV's VideoWriter to encode them into an MP4, and uploads the result.

### Run

```bash
aws glue start-job-run --job-name video-frame-stitcher --region $REGION
```

### Verify

```bash
aws s3 ls s3://glue-video-output-${ACCOUNT_ID}/
```

### Download and view

```bash
aws s3 cp s3://glue-video-output-${ACCOUNT_ID}/sample-annotated.mp4 ./output.mp4 --region $REGION
```

### Key Code (`stitch_video.py`)

```python
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
writer = cv2.VideoWriter(tmp_path, fourcc, fps, (w, h))

for key in sorted_frame_keys:
    img = cv2.imdecode(np.frombuffer(s3_bytes, np.uint8), cv2.IMREAD_COLOR)
    writer.write(img)

writer.release()
s3.upload_file(tmp_path, output_bucket, output_key)
```

### 🎯 Student Exercise

The stitcher job is provided as a reference. Try:

1. **Change the FPS** — override `--FPS` to speed up or slow down the output
2. **Process a different video** — run the full pipeline on `soccer.mp4` or `tennis.mp4`:
   ```bash
   # Extract
   aws glue start-job-run --job-name video-frame-extractor \
     --arguments '{"--INPUT_KEY":"videos/soccer.mp4"}' --region $REGION
   # Annotate
   aws glue start-job-run --job-name video-frame-annotator \
     --arguments '{"--FRAMES_PREFIX":"soccer"}' --region $REGION
   # Stitch
   aws glue start-job-run --job-name video-frame-stitcher \
     --arguments '{"--FRAMES_PREFIX":"soccer-annotated","--OUTPUT_KEY":"soccer-annotated.mp4"}' --region $REGION
   ```
3. **Add a watermark** — overlay text or a logo on each frame before stitching

---

## Full Pipeline (Quick Run)

Run all three labs in sequence for the sample video:

```bash
REGION=ap-south-1

# Lab 1
RUN_ID=$(aws glue start-job-run --job-name video-frame-extractor --region $REGION --query JobRunId --output text)
echo "Lab 1 started: $RUN_ID"
while [ "$(aws glue get-job-run --job-name video-frame-extractor --run-id $RUN_ID --region $REGION --query JobRun.JobRunState --output text)" != "SUCCEEDED" ]; do sleep 10; echo "waiting..."; done
echo "Lab 1 done"

# Lab 2
RUN_ID=$(aws glue start-job-run --job-name video-frame-annotator --region $REGION --query JobRunId --output text)
echo "Lab 2 started: $RUN_ID"
while [ "$(aws glue get-job-run --job-name video-frame-annotator --run-id $RUN_ID --region $REGION --query JobRun.JobRunState --output text)" != "SUCCEEDED" ]; do sleep 10; echo "waiting..."; done
echo "Lab 2 done"

# Lab 3
RUN_ID=$(aws glue start-job-run --job-name video-frame-stitcher --region $REGION --query JobRunId --output text)
echo "Lab 3 started: $RUN_ID"
while [ "$(aws glue get-job-run --job-name video-frame-stitcher --run-id $RUN_ID --region $REGION --query JobRun.JobRunState --output text)" != "SUCCEEDED" ]; do sleep 10; echo "waiting..."; done
echo "Lab 3 done"

# Download result
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 cp s3://glue-video-output-${ACCOUNT_ID}/sample-annotated.mp4 ./output.mp4 --region $REGION
echo "Output: ./output.mp4"
```

## Cleanup

```bash
./cleanup.sh
```

This removes all 3 Glue jobs, 3 S3 buckets, and the IAM role.
