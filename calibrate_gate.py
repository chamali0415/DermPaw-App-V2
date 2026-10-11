"""
Calibrate the invalid-photo gate and get numbers for the report/viva.

You need two folders:
  1. DOG folder  - real dog-skin images, ideally your TEST split
                   (e.g. dataset/test, sub-folders per class are fine)
  2. OTHER folder - 50-100 photos that are NOT dog skin: flowers, food,
                   people, cars, screenshots, cats, furniture, documents...

Run from the backend folder (venv active):
    python calibrate_gate.py --dog dataset/test --other calib/non_dog

It prints, for the current thresholds:
  - % of real dog-skin images ACCEPTED   (want close to 100%)
  - % of non-dog images REJECTED         (want high)
and lists every wrongly-rejected dog image so you can look at them, then
suggests safer threshold values. Put new values in the .env file:
    GATE_ANIMAL_SCORE_MIN=...
    GATE_NON_ANIMAL_TOP1_MIN=...
    GATE_MIN_SKIN_CONFIDENCE=...
"""
import argparse
import os
import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps

import ood_gate

EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")

interpreter = tf.lite.Interpreter(model_path="model/canine_skin_model.tflite")
interpreter.allocate_tensors()
inp = interpreter.get_input_details()[0]["index"]
out = interpreter.get_output_details()[0]["index"]


def skin_probs(img):
    arr = np.array(img.resize((256, 256)), dtype=np.float32)[None, ...]
    interpreter.set_tensor(inp, arr)
    interpreter.invoke()
    return interpreter.get_tensor(out)[0]


def collect(folder):
    paths = []
    for root, _, files in os.walk(folder):
        paths += [os.path.join(root, f) for f in files if f.lower().endswith(EXTS)]
    return sorted(paths)


def evaluate(paths):
    rows = []
    for p in paths:
        try:
            img = ImageOps.exif_transpose(Image.open(p)).convert("RGB")
        except Exception:
            continue
        probs = skin_probs(img)
        ok, reason, d = ood_gate.check_image(img, probs)
        rows.append((p, ok, reason, d))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dog", required=True)
    ap.add_argument("--other", required=True)
    a = ap.parse_args()

    print("Thresholds:", {
        "ANIMAL_SCORE_MIN": ood_gate.ANIMAL_SCORE_MIN,
        "NON_ANIMAL_TOP1_MIN": ood_gate.NON_ANIMAL_TOP1_MIN,
        "MIN_SKIN_CONFIDENCE": ood_gate.MIN_SKIN_CONFIDENCE,
    })
    dog = evaluate(collect(a.dog))
    other = evaluate(collect(a.other))

    dog_acc = sum(r[1] for r in dog) / max(len(dog), 1)
    other_rej = sum(not r[1] for r in other) / max(len(other), 1)
    print(f"\nDog-skin images accepted : {dog_acc:.1%}  ({len(dog)} images)")
    print(f"Non-dog images rejected  : {other_rej:.1%}  ({len(other)} images)")

    bad = [r for r in dog if not r[1]]
    if bad:
        print("\nReal dog images that were WRONGLY rejected:")
        for p, _, reason, d in bad:
            print(f"  {reason:20s} {d}  {p}")
    missed = [r for r in other if r[1]]
    if missed:
        print("\nNon-dog images that slipped through:")
        for p, _, _, d in missed:
            print(f"  {d}  {p}")

    # Suggest thresholds that keep ~99% of real dog images
    animal = np.array([r[3].get("animal_score", 1.0) for r in dog])
    skin = np.array([r[3]["skin_top_confidence"] for r in dog])
    print("\nSuggested (keeps ~99% of real dog images):")
    print(f"  GATE_ANIMAL_SCORE_MIN    <= {np.percentile(animal, 1):.3f}")
    print(f"  GATE_MIN_SKIN_CONFIDENCE <= {np.percentile(skin, 1):.3f}")


if __name__ == "__main__":
    main()
