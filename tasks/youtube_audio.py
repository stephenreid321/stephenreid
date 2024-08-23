import sys
from pytubefix import YouTube

url = sys.argv[1]
path = (
    YouTube(url).streams.filter(file_extension="mp4", only_audio=True).last().download()
)
print(path)
