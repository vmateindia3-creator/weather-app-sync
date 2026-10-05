import requests
import firebase_admin
from firebase_admin import credentials, db
import json
import os

# Firebase initialize karein (GitHub Secret se aayega)
firebase_config = json.loads(os.environ['FIREBASE_SERVICE_ACCOUNT'])
cred = credentials.Certificate(firebase_config)

firebase_admin.initialize_app(cred, {
    'databaseURL': 'Yahan_Apne_Firebase_Database_Ka_URL_Dalein'
})

# OpenWeather API (Apni API key yahan daalein)
API_KEY = "YOUR_OPENWEATHER_API_KEY"
city = "Delhi"
url = f"https://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&appid={API_KEY}"

try:
    response = requests.get(url)
    if response.status_code == 200:
        data = response.json()
        temp = data['main']['temp']
        desc = data['weather'][0]['description']
        
        # Firebase me data save karein
        ref = db.reference('global_temperatures')
        ref.set({
            'city': city,
            'temperature': temp,
            'condition': desc,
            'status': 'Synced from GitHub Actions'
        })
        print("Data successfully synced to Firebase!")
    else:
        print("API Error:", response.status_code)
except Exception as e:
    print(f"Error: {e}")
