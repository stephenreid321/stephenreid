import sys
from pytube import YouTube

url = sys.argv[1]
stream_url = (
    YouTube(url).streams.filter(file_extension="mp4", only_audio=True).last().url
)
print(stream_url)

# requires ffmpeg
# from pydub import AudioSegment
# audio = AudioSegment.from_file(path)
# mp3_path = path.replace(".mp4", ".mp3")
# audio.export(mp3_path, format="mp3")
