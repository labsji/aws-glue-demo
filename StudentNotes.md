# Student Notes — AWS Glue Video Processing Lab

## What You're Building

A serverless video processing pipeline on AWS:

```
MP4 in S3  →  Lab 1: Extract frames  →  Lab 2: Detect & annotate  →  Lab 3: Stitch back to MP4
```

- **Lab 1** — AWS Glue downloads your video and saves one JPG per second to S3
- **Lab 2** — Glue reads each frame, runs a ball-detection algorithm, draws bounding boxes, saves annotated frames
- **Lab 3** — Glue stitches the annotated frames back into an MP4

All three jobs are **AWS Glue Python shell jobs** — serverless, no cluster, billed per second. The interesting part is Lab 2: the detection code is intentionally basic, and your job is to improve it.

---

## Step 1: Sign In

👉 **[Sign in to AWS Console](https://signin.aws.amazon.com/console?account=labsji)** — account alias `labsji` is pre-filled

- Username / Password: shared separately by your instructor
- After sign-in, change your password when prompted

---

## Step 2: Open CloudShell

👉 **[Open CloudShell in Mumbai (ap-south-1)](https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1)**

CloudShell gives you a terminal with AWS credentials already configured — no setup needed.

---

## Step 3: Start the Lab with Kiro

In CloudShell, run this single command:

```bash
bash <(curl -s https://raw.githubusercontent.com/labsji/aws-glue-demo/main/start.sh)
```

This will:
1. Clone the repo into `~/aws-glue-demo`
2. Seed a Kiro conversation with full lab context
3. Launch `kiro-cli chat --resume` — dropping you straight into a guided session

**Kiro already knows the lab.** You can immediately say things like:
- *"run Lab 1"*
- *"explain the detection code"*
- *"improve the ball detection with a circularity filter"*
- *"run the full pipeline on batminton.mp4"*

---

## What Kiro Can Do For You

| Ask Kiro | What happens |
|----------|-------------|
| *"run Lab 1"* | Runs `./run.sh extract sample`, polls until done |
| *"explain annotate_frames.py"* | Walks through the HSV detection logic |
| *"add a red HSV range for cricket balls"* | Edits the file, re-uploads, re-runs Lab 2 |
| *"run the full pipeline"* | Runs all 3 labs in sequence |
| *"show me the output frames"* | Lists S3 keys in the frames bucket |

---

## If You Need to Restart Kiro

```bash
cd ~/aws-glue-demo
kiro-cli chat --resume
```

`--resume` picks up exactly where you left off — your conversation history is preserved.

---

## Cleanup

When you're done, tell Kiro *"clean up all resources"* or run:

```bash
cd ~/aws-glue-demo && ./cleanup.sh
```

---

> Credentials are shared by your instructor. Do not share them or use them outside this lab.
