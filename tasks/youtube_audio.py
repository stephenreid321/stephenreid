import sys
from pytube import YouTube

url = sys.argv[1]
stream_url = (
    YouTube(url).streams.filter(file_extension="mp4", only_audio=True).first().url
)
print(stream_url)
