# Student Notes — AWS Glue Video Processing Lab

## Before You Begin — A Quick Orientation

You're here because you want to build AI agents and intelligent applications. That's a great goal. But before an AI agent can do anything useful, it needs to *run* somewhere — and understanding how code runs in the cloud is the foundation everything else sits on.

This lab is your first encounter with that foundation.

---

### What is "the cloud"?

When you run a Python script on your laptop, your laptop's CPU executes it. The cloud is just someone else's computers — specifically, AWS (Amazon Web Services) owns massive data centres full of servers, and you can rent time on them.

The key insight: **you don't have to manage the hardware**. You write code, tell AWS to run it, and AWS figures out which machine to use, starts it, runs your code, and shuts it down. You pay only for the time your code actually ran.

### What is AWS Glue?

AWS Glue is a service that runs Python (or Scala) scripts on demand — no server to set up, no machine to keep running 24/7. You upload your script, press run, and AWS executes it. When it's done, the compute disappears and you stop paying.

This is what people mean by **"serverless"** — there *are* servers, you just never see or manage them. Compare this to renting a virtual machine (EC2) where you'd have to start it, install Python, keep it running, and remember to turn it off. Glue handles all of that for you.

### What is S3?

S3 (Simple Storage Service) is AWS's file storage. Think of it like Google Drive, but for programs — your code reads and writes files to S3 instead of a local disk. It's durable, cheap, and accessible from anywhere in AWS.

### Why does this matter for AI agents?

An AI agent that does something real — processes images, analyses documents, runs pipelines — needs:
1. **Compute** to run code (Glue, Lambda, EC2...)
2. **Storage** to hold data (S3, databases...)
3. **Orchestration** to chain steps together

This lab gives you hands-on experience with all three. By the end, you'll have run a real data pipeline on AWS infrastructure — the same building blocks used in production AI systems.

---

## What You're Building

A video processing pipeline, entirely in the cloud:

```
MP4 in S3  →  Lab 1: Extract frames  →  Lab 2: Detect & annotate  →  Lab 3: Stitch back to MP4
```

- **Lab 1** — A Glue job downloads your video from S3 and saves one JPG frame per second back to S3
- **Lab 2** — Another Glue job reads each frame, runs a ball-detection algorithm, draws bounding boxes, saves annotated frames
- **Lab 3** — A third Glue job stitches the annotated frames back into an MP4

The interesting part is **Lab 2**: the detection code is intentionally basic, and your job is to improve it. This is where you'll write and deploy real code to a cloud job.

## Step 1: Open CloudShell (Mumbai)

👉 **[https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1](https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1)**

This link opens the AWS sign-in page. Enter:

- **Account alias:** `labsji`
- **Username / Password:** shared separately by your instructor

CloudShell will open in Mumbai (ap-south-1). You may see **"Waiting for terminal session..."** messages for 30–60 seconds — this is normal, just wait.

> Use only Mumbai for this lab — other regions are not permitted for this account.

---

## Step 2: Start the Lab with Kiro

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
