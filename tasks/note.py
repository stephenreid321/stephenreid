import sys
import os
import requests
from dotenv import load_dotenv

load_dotenv()

text = sys.argv[1]
# url = sys.argv[2]

# Start a session.
session = requests.Session()

print(os.environ.get("SUBSTACK_EMAIL"))

# Log in to Substack.
login_url = "https://substack.com/api/v1/login"
login_data = {
    "redirect": "",
    "for_pub": "",
    "email": os.environ.get("SUBSTACK_EMAIL"),
    "password": os.environ.get("SUBSTACK_PASSWORD"),
    "captcha_response": None,
}
login_response = session.post(login_url, json=login_data)

# Bail if we were unable to log in.
if login_response.status_code != 200:
    print(login_response)
    raise ValueError

# Assemble data for Note.
note_url = "https://substack.com/api/v1/comment/feed"
note_headers = {
    "Content-Type": "application/json",
}

note_content = []
for line in text.split("\n"):
    if line:
        note_content.append(
            {"type": "paragraph", "content": [{"type": "text", "text": line}]}
        )
    else:
        note_content.append({"type": "paragraph"})

note_data = {
    "bodyJson": {
        "type": "doc",
        "attrs": {"schemaVersion": "v1"},
        "content": note_content,
    },
    "tabId": "for-you",
    "replyMinimumRole": "everyone",
}

# Post the Note.
note_response = session.post(note_url, headers=note_headers, json=note_data)
print(note_response)
