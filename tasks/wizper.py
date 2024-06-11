import fal_client
import dotenv
import sys
import json

dotenv.load_dotenv()

url = sys.argv[1].replace(" ", "%20")

handler = fal_client.submit(
    "fal-ai/wizper",
    arguments={
        "audio_url": url,
    },
)

result = handler.get()
print(json.dumps(result))
