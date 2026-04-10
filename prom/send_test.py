import firebase_admin
from firebase_admin import credentials, messaging

# 1. Path to the JSON file you downloaded
cred = credentials.Certificate("../service_account.json")
firebase_admin.initialize_app(cred)

# 2. Paste the Registration Token you got from your browser console here
registration_token = 'NiXjhnfNGNiNIE:APA91bHCEc7aRhNOz9Ros42FZe_8PUwx7pHHoL5dpJEOEmxjULRuQc53A5Xy0_XckIwWoxpUM6yGSB4KQgctXWuH3vCnBSWDjnIxxku9b6GwR4YUHD2k1Uo'

message = messaging.Message(
    notification=messaging.Notification(
        title='Success!',
        body='Push notifications are working from Python!',
    ),
    token=registration_token,
)

# Send the message
response = messaging.send(message)
print('Successfully sent message:', response)
