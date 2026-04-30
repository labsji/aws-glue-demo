#!/bin/bash
set -e
cd "$(dirname "$0")"
python3 seed-kiro-session.py
exec kiro-cli chat --resume
