import fal_client
import sys
import json
from dotenv import load_dotenv

load_dotenv()

url = sys.argv[1]

handler = fal_client.submit(
    "fal-ai/wizper",
    arguments={
        "audio_url": url,
    },
)

result = handler.get()
print(json.dumps(result))
