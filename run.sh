#!/bin/bash
set -e

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
INPUT_BUCKET="glue-video-input-${ACCOUNT_ID}-${REGION}"
FRAMES_BUCKET="glue-video-frames-${ACCOUNT_ID}-${REGION}"
OUTPUT_BUCKET="glue-video-output-${ACCOUNT_ID}-${REGION}"

usage() {
  echo "Usage: ./run.sh <command> [video_name]"
  echo ""
  echo "Commands:"
  echo "  extract  <name>   Lab 1: Extract frames from video"
  echo "  annotate <name>   Lab 2: Annotate frames (ball detection)"
  echo "  stitch   <name>   Lab 3: Stitch annotated frames into video"
  echo "  all      <name>   Run all 3 labs in sequence"
  echo "  status            Show latest run status for all jobs"
  echo ""
  echo "Examples:"
  echo "  ./run.sh extract sample"
  echo "  ./run.sh annotate soccer"
  echo "  ./run.sh all tennis"
  echo "  ./run.sh status"
  echo ""
  echo "Available videos: sample, batminton, cloud, dna, flyover, tunneltraffic"
  exit 1
}

wait_for_job() {
  local job=$1 run_id=$2
  echo -n "  Waiting for $job..."
  while true; do
    STATE=$(aws glue get-job-run --job-name "$job" --run-id "$run_id" --region "$REGION" --query JobRun.JobRunState --output text)
    case $STATE in
      SUCCEEDED) echo " ✓ done"; return 0;;
      FAILED|ERROR|TIMEOUT|STOPPED) echo " ✗ $STATE"; return 1;;
      *) echo -n "."; sleep 10;;
    esac
  done
}

CMD="${1:-help}"
VIDEO="${2:-sample}"

case $CMD in
  extract)
    echo "Lab 1: Extracting frames from ${VIDEO}.mp4"
    RUN_ID=$(aws glue start-job-run --job-name video-frame-extractor \
      --arguments "{\"--INPUT_KEY\":\"videos/${VIDEO}.mp4\"}" \
      --region "$REGION" --query JobRunId --output text)
    echo "  Run ID: $RUN_ID"
    wait_for_job video-frame-extractor "$RUN_ID"
    echo "  Output: s3://${FRAMES_BUCKET}/${VIDEO}/"
    ;;

  annotate)
    echo "Lab 2: Annotating frames for ${VIDEO}"
    RUN_ID=$(aws glue start-job-run --job-name video-frame-annotator \
      --arguments "{\"--FRAMES_PREFIX\":\"${VIDEO}\"}" \
      --region "$REGION" --query JobRunId --output text)
    echo "  Run ID: $RUN_ID"
    wait_for_job video-frame-annotator "$RUN_ID"
    echo "  Output: s3://${FRAMES_BUCKET}/${VIDEO}-annotated/"
    ;;

  stitch)
    echo "Lab 3: Stitching annotated frames for ${VIDEO}"
    RUN_ID=$(aws glue start-job-run --job-name video-frame-stitcher \
      --arguments "{\"--FRAMES_PREFIX\":\"${VIDEO}-annotated\",\"--OUTPUT_KEY\":\"${VIDEO}-annotated.mp4\"}" \
      --region "$REGION" --query JobRunId --output text)
    echo "  Run ID: $RUN_ID"
    wait_for_job video-frame-stitcher "$RUN_ID"
    echo "  Output: s3://${OUTPUT_BUCKET}/${VIDEO}-annotated.mp4"
    ;;

  all)
    echo "Running full pipeline for ${VIDEO}.mp4"
    echo ""
    $0 extract "$VIDEO" && $0 annotate "$VIDEO" && $0 stitch "$VIDEO"
    echo ""
    echo "=== Pipeline complete ==="
    echo "Download: aws s3 cp s3://${OUTPUT_BUCKET}/${VIDEO}-annotated.mp4 ./ --region $REGION"
    ;;

  status)
    echo "Latest job run status:"
    for JOB in video-frame-extractor video-frame-annotator video-frame-stitcher; do
      STATE=$(aws glue get-job-runs --job-name "$JOB" --region "$REGION" --query 'JobRuns[0].{State:JobRunState,Duration:ExecutionTime}' --output text 2>/dev/null || echo "NO_RUNS")
      printf "  %-28s %s\n" "$JOB" "$STATE"
    done
    ;;

  *) usage;;
esac
