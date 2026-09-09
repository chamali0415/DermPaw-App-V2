from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, ClassificationResult, Feedback

feedback_bp = Blueprint("feedback", __name__)


@feedback_bp.route("/results/<int:result_id>/feedback", methods=["POST"])
@jwt_required()
def submit_feedback(result_id):
    user_id = get_jwt_identity()

    result = ClassificationResult.query.get(result_id)
    if not result:
        return jsonify({"error": "Classification result not found"}), 404

    data = request.get_json()
    if "feedback_text" not in data or not data["feedback_text"]:
        return jsonify({"error": "feedback_text is required"}), 400

    new_feedback = Feedback(
        result_id=result_id,
        user_id=user_id,
        feedback_text=data["feedback_text"]
    )
    db.session.add(new_feedback)
    db.session.commit()

    return jsonify({
        "message": "Feedback submitted successfully",
        "feedback": new_feedback.to_dict()
    }), 201