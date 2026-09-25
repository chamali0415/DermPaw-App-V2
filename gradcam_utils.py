"""
Grad-CAM for DermPaw (MobileNetV3-Small base + dropout/dense head, 256x256 input).

Needs the Keras model (.keras), NOT the .tflite:
    model.save("canine_skin_mobilenetv3.keras")   # at the end of training

Usage (offline test):
    from gradcam_utils import load_model, gradcam_overlay
    model = load_model("canine_skin_mobilenetv3.keras")
    result = gradcam_overlay(model, "test_dog.jpg", class_names)
    result["overlay"].save("gradcam_out.png")
"""
import base64
import io

import numpy as np
import tensorflow as tf
from PIL import Image
from matplotlib import colormaps

IMG_SIZE = 256
BASE_NAME = "MobileNetV3Small"   # name of the nested base model in model.summary()


def load_model(path):
    # compile=False: we only need forward pass + gradients, and this avoids
    # needing the custom focal-loss function at load time
    return tf.keras.models.load_model(path, compile=False)


def load_image(path_or_file):
    """Returns (float32 array 1x256x256x3 in 0-255, PIL image resized)."""
    img = Image.open(path_or_file).convert("RGB").resize((IMG_SIZE, IMG_SIZE))
    arr = np.asarray(img, dtype=np.float32)
    # IMPORTANT: use exactly the same preprocessing as training.
    # Keras MobileNetV3 has Rescaling built in, so it expects raw 0-255 pixels.
    # If your training pipeline divided by 255 or used preprocess_input, copy that here.
    return np.expand_dims(arr, 0), img


def _build_parts(model):
    base = model.get_layer(BASE_NAME)
    # base was built with pooling="avg", so its last layer is GlobalAveragePooling2D;
    # the layer just before it holds the final 8x8x576 feature map.
    conv_layer = base.layers[-2]
    feat_model = tf.keras.Model(base.input, [conv_layer.output, base.output])
    # layers after the base: dropout, dense, dropout, dense (skip input + base)
    head_layers = model.layers[2:]
    return feat_model, head_layers


def make_gradcam_heatmap(model, img_array, class_idx=None):
    """Returns (heatmap 0-1 of shape HxW, predicted probs, class_idx used)."""
    feat_model, head_layers = _build_parts(model)

    with tf.GradientTape() as tape:
        conv_out, pooled = feat_model(img_array, training=False)
        x = pooled
        for layer in head_layers:
            x = layer(x, training=False)
        preds = x
        if class_idx is None:
            class_idx = int(tf.argmax(preds[0]))
        class_score = preds[:, class_idx]

    grads = tape.gradient(class_score, conv_out)          # (1, h, w, 576)
    weights = tf.reduce_mean(grads, axis=(1, 2))          # (1, 576)
    heatmap = tf.reduce_sum(conv_out * weights[:, None, None, :], axis=-1)[0]
    heatmap = tf.nn.relu(heatmap)
    heatmap = heatmap / (tf.reduce_max(heatmap) + 1e-8)
    return heatmap.numpy(), preds[0].numpy(), class_idx


def overlay_heatmap(pil_img, heatmap, alpha=0.4):
    hm = Image.fromarray(np.uint8(255 * heatmap)).resize(pil_img.size, Image.BILINEAR)
    colored = colormaps["jet"](np.asarray(hm) / 255.0)[:, :, :3]
    colored = Image.fromarray(np.uint8(255 * colored))
    return Image.blend(pil_img, colored, alpha)


def gradcam_overlay(model, path_or_file, class_names, class_idx=None):
    """One-call helper: predicts, builds heatmap, returns overlay + info."""
    arr, pil_img = load_image(path_or_file)
    heatmap, probs, idx = make_gradcam_heatmap(model, arr, class_idx)
    return {
        "overlay": overlay_heatmap(pil_img, heatmap),
        "predicted_class": class_names[idx],
        "confidence": float(probs[idx]),
        "probabilities": {c: float(p) for c, p in zip(class_names, probs)},
    }


def overlay_to_base64(pil_img):
    buf = io.BytesIO()
    pil_img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


# ---------------------------------------------------------------------------
# Flask side (classify.py): keep using the .tflite for the real prediction and
# use the Keras model only for the heatmap. Load the Keras model ONCE at startup.
#
#   from gradcam_utils import load_model, gradcam_overlay, overlay_to_base64
#   keras_model = load_model("models/canine_skin_mobilenetv3.keras")
#
#   # inside your classify route, after the tflite prediction:
#   try:
#       cam = gradcam_overlay(keras_model, image_path, CLASS_NAMES,
#                             class_idx=predicted_index_from_tflite)
#       heatmap_b64 = overlay_to_base64(cam["overlay"])
#   except Exception:
#       heatmap_b64 = None      # never let XAI break the diagnosis
#
#   return jsonify({..., "heatmap": heatmap_b64})
# ---------------------------------------------------------------------------
