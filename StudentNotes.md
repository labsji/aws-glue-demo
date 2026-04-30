# Student Notes — AWS Glue Video Processing Lab

## Step 1: Sign In to AWS Console

Use the link below to sign in with the account alias **labsji**:

👉 **[https://labsji.signin.aws.amazon.com/console](https://labsji.signin.aws.amazon.com/console)**

- **Account alias:** `labsji`
- **Username / Password:** shared separately

After sign-in you will land on the Mumbai (ap-south-1) CloudShell page:

👉 **[https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1#](https://ap-south-1.console.aws.amazon.com/cloudshell/home?region=ap-south-1#)**

---

## Step 2: Two CloudShell Sessions

You will have **two CloudShell tabs** open in the Mumbai region.

| Session | Purpose |
|---------|---------|
| **Session 1 — CLI** | Run the tutorial commands (`./run.sh`, `aws glue ...`) |
| **Session 2 — Kiro** | Interact with Kiro AI to explore and modify the code |

---

## Step 3: Run the Tutorial (Session 1)

Follow **[TUTORIAL.md](TUTORIAL.md)** to run the three labs:

```bash
git clone https://github.com/labsji/aws-glue-demo.git
cd aws-glue-demo
./run.sh extract sample    # Lab 1: video → frames
./run.sh annotate sample   # Lab 2: detect & annotate
./run.sh stitch sample     # Lab 3: frames → video
./run.sh status            # Check job status
```

---

## Step 4: Switch to Kiro (Session 2)

Once you have run at least Lab 1, switch to **Session 2** and start Kiro:

```bash
cd aws-glue-demo
kiro
```

From here, **Kiro takes over the tutorial**. Ask Kiro to explain the code, suggest improvements, or implement the student exercises in `.kiro/specs/improve-ball-detection/requirements.md`.

Example prompts to get started:
- *"Explain what annotate_frames.py does"*
- *"Implement Option B from the spec — add a red HSV range"*
- *"Run Lab 2 after my changes"*

---

> **Note:** Login credentials are shared via a separate channel.
