# Student Notes — AWS Glue Video Processing Lab

## Step 1: Sign In to AWS Console

👉 **[https://labsji.signin.aws.amazon.com/console](https://labsji.signin.aws.amazon.com/console)**

- **Account alias:** `labsji`
- **Username / Password:** shared separately

After sign-in, go directly to CloudShell (Mumbai):

👉 **[https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1#](https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1#)**

---

## Step 2: Two CloudShell Sessions

Open **two CloudShell tabs** in Mumbai. The repo is already cloned in your home directory.

| Session | Purpose |
|---------|---------|
| **Session 1 — CLI** | Run the tutorial labs |
| **Session 2 — Kiro** | AI-assisted code exploration and modification |

---

## Step 3: Run the Tutorial (Session 1)

Press **↑** to recall the last command, or type:

```bash
cd aws-glue-demo
./run.sh extract sample    # Lab 1: video → frames
./run.sh annotate sample   # Lab 2: detect & annotate
./run.sh stitch sample     # Lab 3: frames → video
./run.sh status            # Check job status
```

---

## Step 4: Switch to Kiro (Session 2)

Press **↑** to recall, or type:

```bash
cd aws-glue-demo
kiro-cli chat
```

From here, **Kiro takes over the tutorial**. Example prompts:

- *"Explain what annotate_frames.py does"*
- *"Implement Option B from the spec — add a red HSV range"*
- *"Run Lab 2 after my changes"*

---

> **Note:** Login credentials are shared via a separate channel.
