def fecha():
    from datetime import datetime 
    dt = datetime.now()
    fecha = "{:02}/{:02}/{}".format(dt.day,dt.month,dt.year)
    return fecha

def hora():
    from datetime import datetime 
    dt = datetime.now()
    hora = "{:02}:{:02}".format(dt.hour,dt.minute)
    return hora

# Telegram bot for sending notifications
# Requires the 'requests' library and 'manipulate' module with 'fecha' and 'hora' functions

# Configuration variables definition
BOT_TOKEN=''         # Telegram bot token
USER_ID=''           # Telegram user ID to receive notifications
DEVICE_NAME=''       # Device name for notification message

# Import required libraries
import requests

# Construct webhook URL
webhook_url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage?chat_id={USER_ID}"

# Get message content from input
content = input(str())

# Format notification message
date_message = fecha()
time_message = hora()
message = f"{DEVICE_NAME} Notification from your device on {date_message} at {time_message}\n{content}"

# Prepare JSON payload
data = {"text": message}

# Send POST request to webhook
response = requests.post(webhook_url, json=data)
