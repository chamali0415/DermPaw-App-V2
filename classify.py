import numpy as np
import tensorflow as tf
from PIL import Image
from flask import Blueprint, jsonify
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
VALID_IMAGE_THRESHOLD = 0.4


@classify_bp.route("/images/<int:image_id>/classify", methods=["POST"])
@jwt_required()
def classify_image(image_id):
    image_record = ImageModel.query.get(image_id)
    if not image_record:
        return jsonify({"error": "Image not found"}), 404

    img = Image.open(image_record.image_path).convert("RGB")
    img = img.resize((224, 224))
    arr = np.array(img, dtype=np.float32)
    arr = (arr / 127.5) - 1.0
    arr = np.expand_dims(arr, axis=0)

    interpreter.set_tensor(input_details[0]["index"], arr)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]["index"])[0]

    predicted_index = int(np.argmax(output))
    confidence = float(output[predicted_index])
    predicted_class = CLASS_NAMES[predicted_index]

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
        "is_valid_image": is_valid_image
    }), 201

@classify_bp.route("/results/<int:result_id>/request-review", methods=["POST"])
@jwt_required()
def request_review(result_id):
    result = ClassificationResult.query.get(result_id)
    if not result:
        return jsonify({"error": "Classification result not found"}), 404

    result.review_requested = True
    db.session.commit()

    return jsonify({"message": "Vet review requested successfully", "result": result.to_dict()}), 200

    