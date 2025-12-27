import sys
import os
from dotenv import load_dotenv
load_dotenv()

from atproto import Client
from atproto import models
import requests

text = sys.argv[1]
url = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].strip() else None
title = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].strip() else None
description = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4].strip() else None
image_url = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5].strip() else None

client = Client(base_url='https://bsky.social')
client.login(os.environ.get("BLUESKY_EMAIL"), os.environ.get("BLUESKY_PASSWORD"))

# Only process image if image_url was provided
if image_url:
    try:
        response = requests.get(image_url)
        img_data = response.content
        
        # Check if the image is under 1 MB
        if len(img_data) < 1_000_000:
            try:
                thumb = client.upload_blob(img_data)
                thumb_blob = thumb.blob
            except Exception as e:
                print(f"Failed to upload image")
                thumb_blob = None
        else:
            thumb_blob = None
    except Exception as e:
        print(f"Failed to fetch image")
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
    try:
        post = client.send_post(text, embed=embed)
    except Exception as e:
        print(f"Failed to send post, retrying without image")
        embed = models.AppBskyEmbedExternal.Main(
            external=models.AppBskyEmbedExternal.External(
                title=title or "",  # Use empty string if None
                description=description or "",  # Use empty string if None
                uri=url or "",  # Use empty string if None
            )
        )        
        post = client.send_post(text, embed=embed)
else:
    post = client.send_post(text)