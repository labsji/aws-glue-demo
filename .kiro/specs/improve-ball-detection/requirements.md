# Spec: Improve Ball Detection in annotate_frames.py

## Background

You are working on an AWS Glue video processing pipeline. Lab 2 (`annotate_frames.py`) detects sports balls in video frames using basic HSV color filtering. The tutorial suggests several improvements — your task is to implement one or more of them.

## Current Behaviour

- Two HSV color ranges detect white/bright and orange/yellow objects
- Contours are filtered by area (100–50000 px²) and circularity (> 0.3)
- Detected objects get a green bounding box labelled "ball"

## Your Task

Improve the detection in `annotate_frames.py`. Pick **at least one** of the following:

### Option A — Add morphological cleanup
After building the combined mask, apply `cv2.erode()` and `cv2.dilate()` to remove noise before finding contours.

### Option B — Add a red/pink HSV range
Red wraps around in HSV (hue 0–10 and 170–180). Add a third mask for red objects (cricket ball, red soccer ball).

### Option C — Raise the circularity threshold
Change `circularity > 0.3` to `circularity > 0.6` to reduce false positives and keep only rounder shapes.

### Option D — Use HoughCircles instead of contours
Replace the contour-based detection with `cv2.HoughCircles()` for more robust circular object detection.

## Acceptance Criteria

- [ ] `annotate_frames.py` runs without errors in the Glue job
- [ ] The chosen improvement is clearly visible in the code with a short comment explaining what it does
- [ ] No existing functionality is removed (the bounding box drawing and S3 upload must remain)

## How to Test

After editing, re-upload and re-run:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-south-1

aws s3 cp annotate_frames.py s3://glue-video-input-${ACCOUNT_ID}/scripts/annotate_frames.py --region $REGION
aws glue start-job-run --job-name video-frame-annotator --region $REGION
```

Check the job status:
```bash
./run.sh status
```
