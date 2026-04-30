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

### Preview

Generate a pre-signed URL for any frame and open it in your browser:

```bash
aws s3 presign s3://glue-video-frames-${ACCOUNT_ID}/sample/frame_00005.jpg --expires-in 300
```

Copy the URL into your browser — the JPG renders directly. Try a few different frame numbers to see the extracted images.

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
aws s3 cp sample-video/batminton.mp4 s3://glue-video-input-${ACCOUNT_ID}/videos/batminton.mp4 --region $REGION
aws glue start-job-run --job-name video-frame-extractor \
  --arguments '{"--INPUT_KEY":"videos/batminton.mp4"}' --region $REGION
```

Available: `batminton.mp4`, `cloud.mp4`, `dna.mp4`, `flyover.mp4`, `tunneltraffic.mp4`

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

### Preview

Compare an original frame with its annotated version:

```bash
aws s3 presign s3://glue-video-frames-${ACCOUNT_ID}/sample/frame_00005.jpg --expires-in 300
aws s3 presign s3://glue-video-frames-${ACCOUNT_ID}/sample-annotated/frame_00005.jpg --expires-in 300
```

Open both URLs side by side to see the bounding boxes your detection code drew.

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

Or preview directly in your browser without downloading — generate a pre-signed URL:

```bash
aws s3 presign s3://glue-video-output-${ACCOUNT_ID}/sample-annotated.mp4 --expires-in 300
```

Open the URL in your browser. Most browsers will play the MP4 inline.

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
2. **Process a different video** — run the full pipeline on `batminton.mp4` or `flyover.mp4`:
   ```bash
   # Extract
   aws glue start-job-run --job-name video-frame-extractor \
     --arguments '{"--INPUT_KEY":"videos/batminton.mp4"}' --region $REGION
   # Annotate
   aws glue start-job-run --job-name video-frame-annotator \
     --arguments '{"--FRAMES_PREFIX":"batminton"}' --region $REGION
   # Stitch
   aws glue start-job-run --job-name video-frame-stitcher \
     --arguments '{"--FRAMES_PREFIX":"batminton-annotated","--OUTPUT_KEY":"batminton-annotated.mp4"}' --region $REGION
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

---

## Build It Yourself with Kiro (Advanced)

**Goal:** Recreate this entire pipeline from scratch using only Kiro as your guide — no cloning, no copying. Your end state should match this repo.

This is the real test of understanding. Instead of running pre-written scripts, you'll describe what you want to Kiro in plain English and let it write, deploy, and run everything for you.

### Setup

In CloudShell, start fresh:

```bash
mkdir my-glue-demo && cd my-glue-demo
kiro-cli chat
```

### Step 1 — Bootstrap infrastructure

Tell Kiro:
> *"Create 3 S3 buckets for a video processing pipeline: one for input videos, one for frames, one for output. Use my account ID and region ap-south-1 in the bucket names."*

Then:
> *"Create an IAM role called GlueVideoFrameExtractorRole that Glue can assume, with least-privilege access to those 3 buckets and CloudWatch Logs."*

### Step 2 — Lab 1: Frame extractor

Tell Kiro:
> *"Write a Glue Python shell script that downloads a video from S3, extracts 1 frame per second using OpenCV, and uploads each frame as a JPG to the frames bucket. Then create the Glue job and run it on sample.mp4."*

Verify:
> *"List the frames in S3 and show me a pre-signed URL for one."*

### Step 3 — Lab 2: Frame annotator

Tell Kiro:
> *"Write a Glue Python shell script that reads each JPG frame from S3, detects ball-like objects using HSV color filtering and contour detection, draws green bounding boxes, and saves annotated frames to a separate prefix. Create and run the Glue job."*

Verify:
> *"Show me a pre-signed URL for an annotated frame."*

### Step 4 — Lab 3: Video stitcher

Tell Kiro:
> *"Write a Glue Python shell script that reads all annotated frames from S3 in order, stitches them into an MP4 using OpenCV VideoWriter, and uploads the result to the output bucket with Content-Type video/mp4. Create and run the Glue job."*

Verify:
> *"Give me a pre-signed URL for the output video."*

### Convergence Check

Once your pipeline produces a working annotated video, compare your scripts against the reference repo:

```bash
cd ~
git clone https://github.com/labsji/aws-glue-demo.git reference
diff ~/my-glue-demo/extract_frames.py ~/reference/extract_frames.py
diff ~/my-glue-demo/annotate_frames.py ~/reference/annotate_frames.py
diff ~/my-glue-demo/stitch_video.py ~/reference/stitch_video.py
```

Differences are fine — what matters is that your pipeline produces a playable annotated video. That's the UAT. If it works, your implementation is equivalent.

### What you'll learn from this exercise

- How to direct an AI assistant to build real infrastructure from a description
- What `setup.sh` was actually doing behind the scenes
- Where things break when you build from scratch (permissions, bucket names, codec issues)
- How to use Kiro as a development partner, not just a search engine
