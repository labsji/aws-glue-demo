#!/usr/bin/env python3
"""
Seeds a kiro-cli chat session for the AWS Glue video processing lab.
Run once after cloning the repo. After this, `kiro-cli chat --resume`
picks up the conversation with full lab context already loaded.
"""
import sqlite3, json, uuid, time, os

DB = os.path.expanduser("~/.local/share/kiro-cli/data.sqlite3")
CWD = os.path.expanduser("~/aws-glue-demo")
# Use a far-future timestamp so this session always sorts as most recent
# when the student runs kiro-cli chat --resume
NOW = int(time.time() * 1000)
CONV_ID = str(uuid.uuid4())

ENV = {
    "env_state": {
        "operating_system": "linux",
        "current_working_directory": CWD,
        "environment_variables": []
    }
}

def msg(user_text, assistant_text):
    mid = str(uuid.uuid4())
    return {
        "user": {
            "additional_context": "",
            "env_context": ENV,
            "content": {"Prompt": {"prompt": user_text}},
            "timestamp": "2026-04-30T04:00:00.000000000Z",
            "images": None
        },
        "assistant": {
            "Response": {
                "message_id": mid,
                "content": assistant_text
            }
        },
        "request_metadata": {
            "request_id": str(uuid.uuid4()),
            "message_id": mid,
            "request_start_timestamp_ms": NOW,
            "stream_end_timestamp_ms": NOW + 2000,
            "time_to_first_chunk": {"secs": 2, "nanos": 0},
            "time_between_chunks": []
        }
    }

history = [
    msg(
        "What is this lab about?",
        """This is a 3-lab hands-on workshop that builds a **video processing pipeline on AWS Glue**.

Here's what each lab does:

**Lab 1 — Extract** (`video-frame-extractor`)
Takes an MP4 video stored in S3 and breaks it into individual JPG frames (1 frame per second) using OpenCV. The frames land in your `glue-video-frames-<account>` S3 bucket.

**Lab 2 — Annotate** (`video-frame-annotator`)
Reads those frames, runs a ball-detection algorithm (HSV color filtering + contour detection), draws green bounding boxes around detected balls, and saves annotated frames back to S3.

**Lab 3 — Stitch** (`video-frame-stitcher`)
Reads the annotated frames in order and encodes them back into an MP4 video, which lands in your `glue-video-output-<account>` bucket.

All three jobs run as **AWS Glue Python shell jobs** — serverless, no cluster to manage, billed per DPU-second.

The interesting part for you as a student is **Lab 2**: the detection algorithm in `annotate_frames.py` is intentionally basic. Your job is to improve it.

Ready to run Lab 1? Just say **"run Lab 1"** and I'll kick it off for you."""
    ),
    msg(
        "run Lab 1",
        """Running Lab 1 now — extracting frames from `sample.mp4`.

```
./run.sh extract sample
```

This starts the `video-frame-extractor` Glue job and polls until it completes. It typically takes **2–3 minutes**.

While it runs, here's what's happening under the hood:

1. Glue spins up a Python shell environment (1/16 DPU)
2. `extract_frames.py` downloads `videos/sample.mp4` from your input S3 bucket
3. OpenCV reads the video at its native FPS, samples 1 frame per second
4. Each frame is JPEG-encoded and uploaded to `glue-video-frames-<account>/sample/frame_NNNNN.jpg`

Once it finishes, run `./run.sh annotate sample` for Lab 2, or ask me to explain the detection code first."""
    ),
    msg(
        "explain the detection code in annotate_frames.py",
        """Here's how the ball detection works in `annotate_frames.py`:

**Step 1 — Convert to HSV**
```python
hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
```
HSV (Hue, Saturation, Value) separates color from brightness, making color-based filtering more robust than RGB.

**Step 2 — Two color passes**
```python
# Pass 1: white/bright objects (cricket ball, soccer ball)
mask = cv2.inRange(hsv, [0, 0, 200], [180, 60, 255])

# Pass 2: orange/yellow objects (basketball, tennis ball)
mask2 = cv2.inRange(hsv, [10, 100, 100], [30, 255, 255])

combined = cv2.bitwise_or(mask, mask2)
```
Each `inRange` call produces a binary mask — white pixels where the color matches, black elsewhere.

**Step 3 — Find contours and filter by shape**
```python
contours, _ = cv2.findContours(combined, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
for cnt in contours:
    area = cv2.contourArea(cnt)
    if 100 < area < 5000:          # size filter
        x, y, w, h = cv2.boundingRect(cnt)
        cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
```
Contours that are too small (noise) or too large (background) are discarded.

**Where it falls short:**
- No circularity check — rectangular objects with the right color get flagged
- Fixed HSV ranges don't adapt to lighting changes
- No temporal tracking — each frame is processed independently

**Your exercise:** improve the detection. Some ideas:
- Add a circularity filter: `perimeter²/(4π·area) ≈ 1` for circles
- Use `cv2.HoughCircles()` instead of contours
- Add a red HSV range for cricket balls (wraps around H=0/180)

Want me to implement one of these improvements?"""
    )
]

conversation = {
    "conversation_id": CONV_ID,
    "next_message": None,
    "history": history
}

conn = sqlite3.connect(DB)
cur = conn.cursor()
# Remove any prior sessions for this directory so --resume always lands here
cur.execute("DELETE FROM conversations_v2 WHERE key = ?", (CWD,))
cur.execute(
    "INSERT INTO conversations_v2 (key, conversation_id, value, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
    (CWD, CONV_ID, json.dumps(conversation), NOW - 5000, NOW)
)
conn.commit()
conn.close()

print(f"✅ Kiro session seeded (id: {CONV_ID})")
print(f"   Run:  cd ~/aws-glue-demo && kiro-cli chat --resume")
