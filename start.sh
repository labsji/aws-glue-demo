#!/bin/bash
# First-time setup for students.
# Clones the repo (if needed), seeds the Kiro session, then launches Kiro.
# Usage: bash <(curl -s https://raw.githubusercontent.com/labsji/aws-glue-demo/main/start.sh)

set -e

REPO_DIR="$HOME/aws-glue-demo"

# Clone if not already present
if [ ! -d "$REPO_DIR" ]; then
  echo "Cloning aws-glue-demo..."
  git clone https://github.com/labsji/aws-glue-demo.git "$REPO_DIR"
fi

cd "$REPO_DIR"

# Seed the Kiro conversation history
python3 seed-kiro-session.py

# Hand off to Kiro — student lands in a pre-loaded lab context
exec kiro-cli chat --resume
