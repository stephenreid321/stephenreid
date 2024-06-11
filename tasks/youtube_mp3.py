# requires ffmpeg
import sys
from pytube import YouTube
from pydub import AudioSegment

url = sys.argv[1]

path = (
    YouTube(url).streams.filter(file_extension="mp4", only_audio=True).last().download()
)
audio = AudioSegment.from_file(path)
mp3_path = path.replace(".mp4", ".mp3")
audio.export(mp3_path, format="mp3")
print(mp3_path)
