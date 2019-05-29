from google.cloud import storage
from google.cloud import automl_v1beta1 as automl
import os
import picamera
import datetime
import time as t
import RPi.GPIO as GPIO
from firebase import firebase
 
# AutoML Vision 
project_id = '***********'
compute_region = '***********'
model_id = '***********'
file_path = '***********'
score_threshold = '0.5'
response_display_name = ""

# Firebase
touch = 11
firebase = firebase.FirebaseApplication('***********', None)
touch_original = firebase.get('restart', 'triggeredPressed')
firebase.put('restart', 'triggeredPressed', (not touch_original))

GPIO.setmode(GPIO.BCM)
GPIO.setup(touch, GPIO.IN)

def touch_sensor():
    global touch_original
    touch_pressed = GPIO.input(touch)
    if touch_pressed == touch_original:
        touch_original = (not touch_original)
        firebase.put('restart', 'triggeredPressed', (not touch_original))
        
def analyze():
    global response_display_name
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"]="***********"
    project = '***********'
    storage_client = storage.Client(project=project)
    bucket = storage_client.get_bucket('***********')

    automl_client = automl.AutoMlClient()
    model_full_id = automl_client.model_path(project_id, compute_region, model_id) # Get the full path of the model.

    with open(file_path, "rb") as image_file:
        content = image_file.read()
        payload = {"image": {"image_bytes": content}}

    params = { }

    if score_threshold:
        params = {"score_threshold": score_threshold}

    response = prediction_client.predict(model_full_id, payload, params)
    for result in response.payload:
        print("Date: {} Prediction: {} {}".format(str(datetime.datetime.now()), result.display_name, result.classification.score))

def main():
    while True:
        analyze()
        touch_sensor()

main()
