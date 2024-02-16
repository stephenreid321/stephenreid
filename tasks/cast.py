import sys
import os
from farcaster import Warpcast
from dotenv import load_dotenv

load_dotenv()

text = sys.argv[1]
url = sys.argv[2]
channel = sys.argv[3]

client = Warpcast(mnemonic=os.environ.get("FARCASTER_MNEMONIC"))
response = client.post_cast(text=text, embeds=[url], channel_key=channel)
print(response.cast.hash)
