"""
xai.py  -  Flask-side wrapper for Grad-CAM (put next to classify.py, together with gradcam_utils.py)

The .tflite model still makes the real prediction. This module only builds the
"why" heatmap from the Keras model, for the class the app is about to show.
"""
import os

from gradcam_utils import load_model, gradcam_overlay, overlay_to_base64

# Path to the saved Keras model (adjust if you keep models in another folder)
_BASE = os.path.dirname(os.path.abspath(__file__))
KERAS_MODEL_PATH = os.path.join(_BASE, "model", "canine_skin_mobilenetv3.keras")

# Same labels file that classify.py uses, so the order always matches the tflite output
with open(os.path.join(_BASE, "model", "labels.txt"), "r") as _f:
    CLASS_NAMES = [line.strip() for line in _f.readlines()]

_keras_model = None


def _get_model():
    """Load the Keras model once, on first use, then reuse it."""
    global _keras_model
    if _keras_model is None:
        _keras_model = load_model(KERAS_MODEL_PATH)
    return _keras_model


def get_heatmap_b64(image_path, class_idx):
    """
    Returns a base64 PNG string of the heatmap overlay, or None if anything fails.
    Never raises, so XAI can never break the diagnosis.
    """
    try:
        cam = gradcam_overlay(_get_model(), image_path, CLASS_NAMES, class_idx=class_idx)
        return overlay_to_base64(cam["overlay"])
    except Exception as e:
        print(f"[xai] heatmap failed: {e}")
        return None


# ---------------------------------------------------------------------------
# HOW TO USE IN classify.py
# ---------------------------------------------------------------------------
# 1) At the top:
#        from xai import get_heatmap_b64
#
# 2) In your classify route, AFTER the tflite prediction gives you the predicted
#    class index and AFTER the image is saved to disk:
#
#        predicted_index = int(np.argmax(output_probs))        # your existing variable
#        heatmap_b64 = get_heatmap_b64(saved_image_path, predicted_index)
#
# 3) Add it to the JSON you already return:
#
#        return jsonify({
#            ...your existing fields...,
#            "heatmap": heatmap_b64          # None if it failed
#        }), 200
#
# No database change is needed. If you also want to re-show the heatmap later in
# History, either save it to a file, or recompute it with get_heatmap_b64().
