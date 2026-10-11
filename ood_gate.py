"""
Invalid-photo gate (out-of-distribution check) for DermPaw.

WHY THIS EXISTS
Our skin model is a 5-class classifier. Softmax ALWAYS spreads 100% across
those 5 classes, so a photo of roses still comes out as e.g. "Ringworm 36%".
A classifier cannot say "none of the above" on its own.

HOW IT WORKS (two stages)
  Stage 1 - "Is this an animal / fur / skin photo at all?"
     A general MobileNetV2 trained on ImageNet (1000 everyday classes) looks
     at the photo. ImageNet classes 0-397 are animals (151-268 are dog breeds).
     We add up the probability of all animal classes plus a few fur/fabric-
     texture classes (close-up skin and fur photos often look like "wool" or
     "fur coat" to ImageNet). If that total is very low AND the model is fairly
     sure it is something else (flowers, food, cars, screenshots...), we reject.

  Stage 2 - "Is the skin model confident enough to say anything?"
     With 5 classes, random guessing is 20%. If the skin model's top class is
     below MIN_SKIN_CONFIDENCE it is essentially guessing, so we reject.

Both thresholds are set by calibrate_gate.py on real dataset images and a
folder of non-dog photos, so the numbers can be justified in the viva.
"""
import os
import numpy as np
from dotenv import load_dotenv

load_dotenv()  # app.py loads .env after importing blueprints, so load it here too

# ---- Thresholds (tune with calibrate_gate.py) --------------------------------
ANIMAL_SCORE_MIN = float(os.getenv("GATE_ANIMAL_SCORE_MIN", "0.15"))
NON_ANIMAL_TOP1_MIN = float(os.getenv("GATE_NON_ANIMAL_TOP1_MIN", "0.20"))
MIN_SKIN_CONFIDENCE = float(os.getenv("GATE_MIN_SKIN_CONFIDENCE", "0.30"))

GATE_MODEL_PATH = "model/imagenet_gate.keras"

# ImageNet indices 0-397 = animals (fish, birds, reptiles, mammals, dogs...)
ANIMAL_INDICES = np.arange(0, 398)
# Fur / fabric / skin-texture look-alikes. Close-up dog skin is often
# labelled as one of these by ImageNet, so they count as "dog-like".
TEXTURE_INDICES = np.array([
    419,  # Band_Aid
    434,  # bath_towel
    474,  # cardigan
    529,  # diaper
    539,  # doormat
    568,  # fur_coat
    591,  # handkerchief
    658,  # mitten
    741,  # prayer_rug
    750,  # quilt
    793,  # shower_cap
    806,  # sock
    824,  # stole
    840,  # swab
    841,  # sweatshirt
    885,  # velvet
    911,  # wool
])
DOG_LIKE_INDICES = set(ANIMAL_INDICES.tolist()) | set(TEXTURE_INDICES.tolist())

_gate_model = None
_gate_load_failed = False


def _load_gate_model():
    """Load once, on first use. Never crash classification if it fails."""
    global _gate_model, _gate_load_failed
    if _gate_model is not None or _gate_load_failed:
        return _gate_model
    try:
        import tensorflow as tf
        if os.path.exists(GATE_MODEL_PATH):
            _gate_model = tf.keras.models.load_model(GATE_MODEL_PATH)
        else:
            # Downloads ~14 MB of ImageNet weights the first time
            _gate_model = tf.keras.applications.MobileNetV2(weights="imagenet")
        print("[ood_gate] ImageNet gate model loaded")
    except Exception as e:
        _gate_load_failed = True
        print(f"[ood_gate] WARNING: gate model unavailable, stage 1 skipped: {e}")
    return _gate_model


def warm_up():
    """Call at server start so the first scan in a demo isn't slow."""
    _load_gate_model()


def imagenet_scores(pil_rgb_image):
    """Returns (animal_score, top1_index, top1_prob) or None if no gate model."""
    model = _load_gate_model()
    if model is None:
        return None
    import tensorflow as tf
    img = pil_rgb_image.resize((224, 224))
    arr = np.array(img, dtype=np.float32)[None, ...]
    arr = tf.keras.applications.mobilenet_v2.preprocess_input(arr)
    probs = model.predict(arr, verbose=0)[0]
    animal_score = float(probs[ANIMAL_INDICES].sum() + probs[TEXTURE_INDICES].sum())
    top1 = int(np.argmax(probs))
    return animal_score, top1, float(probs[top1])


def check_image(pil_rgb_image, skin_probs):
    """
    Decide whether a photo is a valid dog-skin photo.
    skin_probs: the 5-class output of our skin model (numpy array, sums to 1).
    Returns (is_valid: bool, reason: str, details: dict)
    """
    details = {"skin_top_confidence": round(float(np.max(skin_probs)), 4)}

    scores = imagenet_scores(pil_rgb_image)
    if scores is not None:
        animal_score, top1, top1_prob = scores
        details.update({
            "animal_score": round(animal_score, 4),
            "imagenet_top1_index": top1,
            "imagenet_top1_prob": round(top1_prob, 4),
        })
        if (animal_score < ANIMAL_SCORE_MIN
                and top1 not in DOG_LIKE_INDICES
                and top1_prob >= NON_ANIMAL_TOP1_MIN):
            return False, "not_animal", details

    if float(np.max(skin_probs)) < MIN_SKIN_CONFIDENCE:
        return False, "low_skin_confidence", details

    return True, "ok", details
