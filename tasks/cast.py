import sys
import os
from farcaster import Warpcast
from dotenv import load_dotenv

load_dotenv()

text = sys.argv[1]
url = sys.argv[2]

client = Warpcast(mnemonic=os.environ.get("FARCASTER_MNEMONIC"))
response = client.post_cast(text=text, embeds=[url])
print(response.cast.hash)
