# worker.py
import requests


def make_get_request():
    response = requests.get('https://stephenreid.net/python')
    if response.status_code == 200:
        print(response.json())
    else:
        print(f"Error {response.status_code}: {response.text}")


if __name__ == "__main__":
    make_get_request()
