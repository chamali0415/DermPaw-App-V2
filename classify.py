import numpy as np
import tensorflow as tf
from PIL import Image
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from models import db, Image as ImageModel, ClassificationResult

classify_bp = Blueprint("classify", __name__)

interpreter = tf.lite.Interpreter(model_path="model/canine_skin_model.tflite")
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

with open("model/labels.txt", "r") as f:
    CLASS_NAMES = [line.strip() for line in f.readlines()]

CONFIDENCE_THRESHOLD = 0.5
VALID_IMAGE_THRESHOLD = 0.25

SYMPTOM_ADJUSTMENTS = {
    # Ringworm
    "circular_lesions": {"Ringworm": 1.7},
    "brittle_claws": {"Ringworm": 1.4},
    "low_itch_despite_lesions": {
        "Ringworm": 1.3,
        "Mange": 0.7,
        "Hypersensitivity Allergy(Tick dermatitis)": 0.7,
    },

    # Mange
    "severe_itch_worse_at_night": {"Mange": 1.7},
    "heavy_crusting": {"Mange": 1.5},

    # Fungal(Dandruff)
    "greasy_coat": {"Fungal(Dandruff)": 1.6},
    "coat_odor": {"Fungal(Dandruff)": 1.4},
    "ear_involvement": {"Fungal(Dandruff)": 1.4},

    # Hypersensitivity Allergy(Tick dermatitis)
    "localized_lesion_at_bite_point": {"Hypersensitivity Allergy(Tick dermatitis)": 1.6},
    "only_one_area_not_spreading": {"Hypersensitivity Allergy(Tick dermatitis)": 1.3},

    # Healthy (baseline)
    "normal_coat_no_issues": {"Healthy": 1.8},
}


@classify_bp.route("/images/<int:image_id>/classify", methods=["POST"])
@jwt_required()
def classify_image(image_id):
    image_record = ImageModel.query.get(image_id)
    if not image_record:
        return jsonify({"error": "Image not found"}), 404

    img = Image.open(image_record.image_path).convert("RGB")
    img = img.resize((256, 256))
    arr = np.array(img, dtype=np.float32)
    arr = np.expand_dims(arr, axis=0)

    interpreter.set_tensor(input_details[0]["index"], arr)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]["index"])[0]

    predicted_index = int(np.argmax(output))
    confidence = float(output[predicted_index])
    predicted_class = CLASS_NAMES[predicted_index]
    probabilities = {
        CLASS_NAMES[i]: round(float(p) * 100, 1) for i, p in enumerate(output)
    }

    needs_vet_review = confidence < CONFIDENCE_THRESHOLD
    is_valid_image = confidence >= VALID_IMAGE_THRESHOLD

    result = ClassificationResult(
        image_id=image_id,
        predicted_disease=predicted_class,
        confidence_score=confidence
    )
    db.session.add(result)
    db.session.commit()

    return jsonify({
        "message": "Classification complete",
        "result_id": result.result_id,
        "predicted_disease": predicted_class,
        "confidence_score": round(confidence, 4),
        "needs_vet_review": needs_vet_review,
        "is_valid_image": is_valid_image,
        "probabilities": probabilities
    }), 201


@classify_bp.route("/results/refine", methods=["POST"])
@jwt_required()
def refine_with_symptoms():
    data = request.get_json()
    probabilities = data.get("probabilities", {})
    symptoms = data.get("symptoms", [])

    adjusted = dict(probabilities)

    for symptom in symptoms:
        weights = SYMPTOM_ADJUSTMENTS.get(symptom, {})
        for cls, factor in weights.items():
            if cls in adjusted:
                adjusted[cls] *= factor

    total = sum(adjusted.values())
    if total > 0:
        adjusted = {cls: round((val / total) * 100, 1) for cls, val in adjusted.items()}

    predicted_class = max(adjusted, key=adjusted.get)
    confidence = adjusted[predicted_class] / 100

    return jsonify({
        "predicted_disease": predicted_class,
        "confidence_score": round(confidence, 4),
        "needs_vet_review": confidence < CONFIDENCE_THRESHOLD,
        "probabilities": adjusted
    }), 200


@classify_bp.route("/results/<int:result_id>/request-review", methods=["POST"])
@jwt_required()
def request_review(result_id):
    result = ClassificationResult.query.get(result_id)
    if not result:
        return jsonify({"error": "Classification result not found"}), 404

    result.review_requested = True
    db.session.commit()

    return jsonify({"message": "Vet review requested successfully", "result": result.to_dict()}), 200