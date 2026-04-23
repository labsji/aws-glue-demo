import sys
import os
import tempfile
import boto3
import cv2
import numpy as np
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ['FRAMES_BUCKET', 'FRAMES_PREFIX', 'OUTPUT_BUCKET', 'OUTPUT_KEY', 'FPS'])
s3 = boto3.client('s3')

# List annotated frames
prefix = args['FRAMES_PREFIX'].rstrip('/') + '/'
resp = s3.list_objects_v2(Bucket=args['FRAMES_BUCKET'], Prefix=prefix)
keys = sorted([o['Key'] for o in resp.get('Contents', []) if o['Key'].endswith('.jpg')])
print(f"Found {len(keys)} frames to stitch")

if not keys:
    print("No frames found, exiting")
    sys.exit(0)

# Download first frame to get dimensions
obj = s3.get_object(Bucket=args['FRAMES_BUCKET'], Key=keys[0])
img = cv2.imdecode(np.frombuffer(obj['Body'].read(), np.uint8), cv2.IMREAD_COLOR)
h, w = img.shape[:2]
fps = int(args['FPS'])

# Create video writer
tmp_path = tempfile.mktemp(suffix='.mp4')
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
writer = cv2.VideoWriter(tmp_path, fourcc, fps, (w, h))
writer.write(img)

# Write remaining frames
for key in keys[1:]:
    obj = s3.get_object(Bucket=args['FRAMES_BUCKET'], Key=key)
    img = cv2.imdecode(np.frombuffer(obj['Body'].read(), np.uint8), cv2.IMREAD_COLOR)
    writer.write(img)

writer.release()

# Upload video
s3.upload_file(tmp_path, args['OUTPUT_BUCKET'], args['OUTPUT_KEY'])
os.unlink(tmp_path)
print(f"Stitched video → s3://{args['OUTPUT_BUCKET']}/{args['OUTPUT_KEY']}")
