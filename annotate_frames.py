import sys
import os
import io
import boto3
import cv2
import numpy as np
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ['FRAMES_BUCKET', 'FRAMES_PREFIX', 'OUTPUT_BUCKET'])
s3 = boto3.client('s3')

# List all frames
prefix = args['FRAMES_PREFIX'].rstrip('/') + '/'
resp = s3.list_objects_v2(Bucket=args['FRAMES_BUCKET'], Prefix=prefix)
keys = sorted([o['Key'] for o in resp.get('Contents', []) if o['Key'].endswith('.jpg')])
print(f"Found {len(keys)} frames to annotate")

for key in keys:
    # Download frame
    obj = s3.get_object(Bucket=args['FRAMES_BUCKET'], Key=key)
    img_bytes = obj['Body'].read()
    img = cv2.imdecode(np.frombuffer(img_bytes, np.uint8), cv2.IMREAD_COLOR)

    # Convert to HSV for color-based ball detection
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # Detect bright/white objects (works for most sports balls)
    lower = np.array([0, 0, 200])
    upper = np.array([180, 60, 255])
    mask = cv2.inRange(hsv, lower, upper)

    # Also detect orange/yellow (basketball, tennis ball)
    lower2 = np.array([10, 100, 100])
    upper2 = np.array([30, 255, 255])
    mask2 = cv2.inRange(hsv, lower2, upper2)
    mask = cv2.bitwise_or(mask, mask2)

    # Find contours
    mask = cv2.GaussianBlur(mask, (5, 5), 0)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Filter by size and circularity — draw bounding boxes
    detected = 0
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if 100 < area < 50000:
            perimeter = cv2.arcLength(cnt, True)
            if perimeter > 0:
                circularity = 4 * 3.14159 * area / (perimeter * perimeter)
                if circularity > 0.3:
                    x, y, w, h = cv2.boundingRect(cnt)
                    cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 2)
                    cv2.putText(img, "ball", (x, y - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                    detected += 1

    # Add annotation count overlay
    cv2.putText(img, f"Detected: {detected}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)

    # Upload annotated frame
    _, buf = cv2.imencode('.jpg', img)
    out_key = key.replace(args['FRAMES_PREFIX'].rstrip('/'), args['FRAMES_PREFIX'].rstrip('/') + '-annotated')
    s3.put_object(Bucket=args['OUTPUT_BUCKET'], Key=out_key, Body=buf.tobytes(), ContentType='image/jpeg')

print(f"Annotated {len(keys)} frames → s3://{args['OUTPUT_BUCKET']}/{prefix.replace(prefix.split('/')[0], prefix.split('/')[0] + '-annotated')}")
