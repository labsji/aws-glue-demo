#!/bin/bash
set -e
cd "$(dirname "$0")"
python3 seed-kiro-session.py
exec kiro-cli chat --resume "Welcome the student to the AWS Glue Video Processing Lab. Introduce yourself briefly, tell them the 3 labs they'll run today, and ask them if they're ready to start with Lab 1."
