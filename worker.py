import os
from telegram import Bot
import asyncio


async def send_message():
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    bot = Bot(token=token)
    await bot.send_message(chat_id="@stephenreid321", text="hey there")


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(send_message())
