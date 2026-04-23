import sys
import os
import boto3
import cv2
import tempfile
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ['INPUT_BUCKET', 'INPUT_KEY', 'OUTPUT_BUCKET'])
s3 = boto3.client('s3')

with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as tmp:
    s3.download_file(args['INPUT_BUCKET'], args['INPUT_KEY'], tmp.name)
    tmp_path = tmp.name

video_name = os.path.splitext(os.path.basename(args['INPUT_KEY']))[0]
cap = cv2.VideoCapture(tmp_path)
fps = cap.get(cv2.CAP_PROP_FPS)
interval = int(fps) if fps > 0 else 30  # extract 1 frame per second

frame_num = 0
saved = 0
while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    if frame_num % interval == 0:
        _, buf = cv2.imencode('.jpg', frame)
        key = f"{video_name}/frame_{saved:05d}.jpg"
        s3.put_object(Bucket=args['OUTPUT_BUCKET'], Key=key, Body=buf.tobytes(), ContentType='image/jpeg')
        saved += 1
    frame_num += 1

cap.release()
os.unlink(tmp_path)
print(f"Extracted {saved} frames from {args['INPUT_KEY']}")
