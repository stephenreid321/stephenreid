import os
from telegram import Bot


def send_message():
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    bot = Bot(token=token)
    bot.send_message(chat_id="@stephenreid321", text=message)


if __name__ == "__main__":
    send_message()
