import os
from telegram import Bot
import asyncio


async def send_message():
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    bot = Bot(token=token)
    message = "Welcome to all new members! Please make sure you've read the pinned post 👆, and do try to keep discussion in this channel to a minimum - instead, post in your local Circle(s) 🙏"
    await bot.send_message(chat_id=-1001592559430, reply_to_message_id=2, text=message)


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(send_message())
