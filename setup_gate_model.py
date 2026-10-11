"""
One-time setup: download the ImageNet MobileNetV2 used by the invalid-photo
gate and save it inside the project, so the server never needs to download it
at runtime (important on the Azure VM and during the viva demo).

Run from the backend folder (venv active):
    python setup_gate_model.py
Creates: model/imagenet_gate.keras  (~14 MB)
"""
import os
import tensorflow as tf

os.makedirs("model", exist_ok=True)
model = tf.keras.applications.MobileNetV2(weights="imagenet")
model.save("model/imagenet_gate.keras")
print("Saved model/imagenet_gate.keras")
