#!/bin/bash
sudo apt update
sudo apt install python3 python3-venv python3-pip ffmpeg -y

mkdir bot
cd bot

python3 -m venv venv
source venv/bin/activate

pip install python-telegram-bot yt-dlp python-dotenv

echo Enter your telegram api key:

read API

echo "TG_API_KEY='$API'" > .env

cat << 'EOF' > bot.py
from telegram import Update
from telegram.ext import ApplicationBuilder, MessageHandler, filters, ContextTypes
import os
from dotenv import load_dotenv
import yt_dlp
import os

load_dotenv()

async def download(update: Update, context: ContextTypes.DEFAULT_TYPE):
    url = update.message.text

    await update.message.reply_text("⏳ Downloading...")

    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': '%(artist)s - %(title)s.%(ext)s',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
        }],
        'quiet': True
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)

            filename = ydl.prepare_filename(info)
            filename = filename.replace(info['ext'], 'mp3')

        title = info.get('title', 'Unknown')
        artist = info.get('artist', '') or info.get('uploader', '')

        await update.message.reply_audio(
            audio=open(filename, 'rb'),
            title=title,
            performer=artist
        )

        os.remove(filename)

    except Exception as e:
        await update.message.reply_text("❌ Error")
        print(e)

app = ApplicationBuilder().token(os.getenv('TG_API_KEY')).build()
app.add_handler(MessageHandler(filters.TEXT, download))

app.run_polling()
EOF

cat << 'EOF' > /etc/systemd/system/telegram-bot.service
[Unit]
Description=Telegram YouTube Bot
After=network.target

[Service]
User=root
WorkingDirectory=/root/bot
ExecStart=/root/bot/venv/bin/python /root/bot/bot.py
EnvironmentFile=/root/bot/.env
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot
sudo systemctl start telegram-bot
