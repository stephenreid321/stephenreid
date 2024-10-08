import sys
import os
from dotenv import load_dotenv
load_dotenv()

from atproto import Client
from atproto import models
import requests

text = sys.argv[1]
title = sys.argv[2]
url = sys.argv[3]
description = sys.argv[4]
image_url = sys.argv[5]

client = Client(base_url='https://bsky.social')
client.login(os.environ.get("BLUESKY_EMAIL"), os.environ.get("BLUESKY_PASSWORD"))

response = requests.get(image_url)
img_data = response.content

# Check if the image is under 1 MB
if len(img_data) < 1_000_000:
    thumb = client.upload_blob(img_data)
    thumb_blob = thumb.blob
else:
    thumb_blob = None

embed = models.AppBskyEmbedExternal.Main(
    external=models.AppBskyEmbedExternal.External(
        title=title,
        description=description,
        uri=url,
        thumb=thumb_blob
    )
)
post = client.send_post(text, embed=embed)