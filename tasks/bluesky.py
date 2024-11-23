import sys
import os
from dotenv import load_dotenv
load_dotenv()

from atproto import Client
from atproto import models
import requests

text = sys.argv[1]
url = sys.argv[2] if len(sys.argv) > 2 else None
title = sys.argv[3] if len(sys.argv) > 3 else None
description = sys.argv[4] if len(sys.argv) > 4 else None
image_url = sys.argv[5] if len(sys.argv) > 5 else None

client = Client(base_url='https://bsky.social')
client.login(os.environ.get("BLUESKY_EMAIL"), os.environ.get("BLUESKY_PASSWORD"))

# Only process image if image_url was provided
if image_url:
    response = requests.get(image_url)
    img_data = response.content
    
    # Check if the image is under 1 MB
    if len(img_data) < 1_000_000:
        thumb = client.upload_blob(img_data)
        thumb_blob = thumb.blob
    else:
        thumb_blob = None
else:
    thumb_blob = None

# Only create embed if at least title or url is provided
if title or url:
    embed = models.AppBskyEmbedExternal.Main(
        external=models.AppBskyEmbedExternal.External(
            title=title or "",  # Use empty string if None
            description=description or "",  # Use empty string if None
            uri=url or "",  # Use empty string if None
            thumb=thumb_blob
        )
    )
    post = client.send_post(text, embed=embed)
else:
    post = client.send_post(text)