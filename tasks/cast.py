import sys
import os
from dotenv import load_dotenv
load_dotenv()

from farcaster import Warpcast

text = sys.argv[1]
url = sys.argv[2]
channel = sys.argv[3] if len(sys.argv) > 3 else None

client = Warpcast(mnemonic=os.environ.get("FARCASTER_MNEMONIC"))
response = client.post_cast(text=text, embeds=[url], channel_key=channel)
print(response.cast.hash)
