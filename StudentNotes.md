# Student Notes — AWS Glue Video Processing Lab

## Before You Begin — A Quick Orientation

You're here because you want to build AI agents and intelligent applications. That's a great goal. But before an AI agent can do anything useful, it needs to *run* somewhere — and understanding how code runs in the cloud is the foundation everything else sits on.

This lab is your first encounter with that foundation. And here's the thing — **your first brush with the cloud is going to be smooth**. Not because the cloud is simple, but because a lot has been set up for you already, and you have an AI pair right beside you.

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

## Your Secret Weapons: CloudShell + Kiro

Two things make this lab unusually approachable for a first cloud experience.

**AWS CloudShell** is a terminal that runs *inside your browser*, directly in the AWS console. There's nothing to install, no SSH keys to configure, no local environment to set up. You open a URL, and you have a fully functional Linux shell with AWS credentials already loaded. It's AWS's way of saying: just start typing.

**Kiro** is your AI coding assistant, running right inside that shell. It knows this lab, knows the codebase, and can read files, run commands, and explain what's happening — all in plain conversation. Instead of hunting through documentation or guessing at commands, you just ask.

Together, they collapse what would normally be a multi-hour environment setup into a single URL and one command. **The terminal is your cloud. The conversation is your interface.**

Here's what that looks like in practice:

| Without CloudShell + Kiro | With CloudShell + Kiro |
|---------------------------|------------------------|
| Install AWS CLI locally | Already available in CloudShell |
| Configure credentials | Pre-loaded in the session |
| Read docs to find the right command | Ask Kiro |
| Debug a failing Glue job alone | Kiro reads the logs and explains |
| Edit code, re-upload manually | Kiro edits, uploads, and re-runs |

---

## This Account Is Pre-Set Up — Here's What That Means

When you start this lab, a lot of the hard work is already done:

- **S3 buckets** are created and named correctly
- **IAM role** with the right permissions is in place
- **Glue jobs** are registered and ready to run
- **Sample videos** are uploaded and waiting
- **Python dependencies** (OpenCV, etc.) are packaged and available to Glue

In a real project, setting all of this up correctly is where most beginners get stuck — permissions errors, missing buckets, wrong regions. You're skipping that friction today so you can focus on what matters: **understanding the flow, running the pipeline, and writing real code**.

This is intentional. Your first brush with the cloud should feel like a success, not a debugging marathon.

---

## What You're Building

A video processing pipeline, entirely in the cloud:

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  MP4 Video      │    │  Lab 1           │    │  Lab 2           │    │  Lab 3          │
│  stored in S3   │───▶│  Extract frames  │───▶│  Detect &        │───▶│  Stitch frames  │
│                 │    │  as JPG images   │    │  annotate balls  │    │  back to MP4    │
└─────────────────┘    └──────────────────┘    └──────────────────┘    └─────────────────┘
```

- **Lab 1** — A Glue job downloads your video from S3 and saves one JPG frame per second back into S3
- **Lab 2** — Another Glue job reads each frame, runs a ball-detection algorithm, draws bounding boxes, saves annotated frames
- **Lab 3** — A third Glue job stitches the annotated frames back into an MP4

The interesting part is **Lab 2**: the detection code is intentionally basic, and your job is to improve it. This is where you'll write and deploy real code to a cloud job.

---

## What You'll Take Away From This Lab

This isn't just a video processing exercise. Here's what you're actually building familiarity with:

**1. AWS CloudShell — your browser-based terminal**
No installs, no credentials to configure. You'll see firsthand how CloudShell gives you a fully functional Linux shell with AWS access in seconds. That's a superpower for anyone working in the cloud.

**2. Kiro — an AI coding assistant that works alongside you**
Kiro isn't just a chatbot. It reads your code, runs commands, edits files, and explains what's happening — all in conversation. This tutorial itself was built with Kiro's assistance. By the end of today, you'll have a feel for how to use it as a real development partner.

**3. AWS Glue — serverless compute for data work**
You'll run three real Glue jobs that process video files stored in S3. No servers to manage. You'll see how Glue fits into a data pipeline and why it's a practical choice for batch processing tasks.

**4. A task to take home — add audio to video using Glue**
Once you've completed the three labs, here's your challenge:

> Create a new folder in this repo. Write an AWS Glue job that takes a video file (e.g. `batminton.mp4`) and its matching audio file (`batminton.mp3`) from S3, merges them, and uploads the result.

This is open-ended by design. Use Kiro to help you figure it out — ask it to scaffold the code, explain `ffmpeg` or `moviepy` options, write the Glue job, and deploy it. The goal is to experience what it feels like to build something real with an AI assistant from scratch.

---

## Step 1: Open CloudShell (Mumbai)

👉 **[https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1](https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1)**

This link opens the AWS sign-in page. Enter:

- **Account alias:** `labsji`
- **Username / Password:** shared separately by your instructor

CloudShell will open in Mumbai (ap-south-1). You may see **"Waiting for terminal session..."** messages for 30–60 seconds — this is normal, just wait.

> Use only Mumbai for this lab — other regions are not permitted for this account.

---

## 👀 Explore the Console — Before and After

Don't just run commands blindly. The AWS console is your window into what's actually happening. Make it a habit to look.

**Before running any lab**, open these in your browser:

- **S3 Console** → [https://s3.console.aws.amazon.com/s3/buckets](https://s3.console.aws.amazon.com/s3/buckets)
  Browse the input bucket. Find your video file. Notice the folder structure.

- **AWS Glue Console** → [https://ap-south-1.console.aws.amazon.com/glue/home?region=ap-south-1#/v2/jobs](https://ap-south-1.console.aws.amazon.com/glue/home?region=ap-south-1#/v2/jobs)
  See the three jobs listed: `video-frame-extractor`, `video-frame-annotator`, `video-frame-stitcher`. Click one and look at its script and configuration.

**After running a lab**, go back to S3 and look at the output bucket. You'll see the frames appear — actual JPG files created by code you triggered. That's your pipeline working.

Visualising the before/after in the console turns abstract commands into something concrete. You'll understand *why* the pipeline is structured the way it is.

---

## Step 2: Start the Lab with Kiro

In CloudShell, run:

```bash
cd aws-glue-demo
./start.sh
```

This loads the lab context and launches Kiro — dropping you straight into a guided session.

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

## Try This on Your Own AWS Account

Today's lab ran on a pre-configured account. But everything you did here — the S3 buckets, the Glue jobs, the IAM role — can be recreated in minutes on your own AWS Free Tier account.

**Your learning objective for after this lab:**
> Set up and run this same pipeline from scratch in your own AWS account. No pre-configuration. No instructor account. Just you, the AWS console, and the `setup.sh` script.

Here's how:

1. Create a free AWS account at [https://aws.amazon.com/free](https://aws.amazon.com/free)
2. Open CloudShell in your account
3. Clone the repo and run `./setup.sh` — it creates everything from scratch
4. Run the labs with `./run.sh`
5. When done, run `./cleanup.sh` to tear everything down and avoid charges

This is the real test of understanding. When *you* set it up, you'll see exactly what the pre-configuration was hiding — and you'll learn from it. The Free Tier covers the compute and storage used in this lab comfortably for a few runs.

---

> Credentials for today's lab are shared by your instructor. Do not share them or use them outside this session.
