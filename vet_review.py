from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, ClassificationResult, VetReview

vet_review_bp = Blueprint("vet_review", __name__)


def require_vet(user_id):
    user = User.query.get(user_id)
    if not user or not user.is_vet:
        return False
    return True


def require_verified_vet(user_id):
    user = User.query.get(user_id)
    if not user or not user.is_vet:
        return None
    if not user.is_verified:
        return "unverified"
    return user

import os
from flask import send_file

@vet_review_bp.route("/images/<int:image_id>/file", methods=["GET"])
@jwt_required()
def get_image_file(image_id):
    from models import Image as ImageModel

    image = ImageModel.query.get(image_id)
    if not image:
        return jsonify({"error": "Image not found"}), 404

    if not os.path.exists(image.image_path):
        return jsonify({"error": "Image file missing on server"}), 404

    return send_file(image.image_path)

@vet_review_bp.route("/vet/reviews", methods=["GET"])
@jwt_required()
def get_pending_reviews():
    user_id = get_jwt_identity()
    if not require_vet(user_id):
        return jsonify({"error": "Only veterinarians can access this route"}), 403

    reviewed_result_ids = [r.result_id for r in VetReview.query.all()]
    pending = (
        ClassificationResult.query.filter(
            ~ClassificationResult.result_id.in_(reviewed_result_ids)
        )
        .filter(
            (ClassificationResult.review_requested == True)
            | (ClassificationResult.confidence_score < 0.5)
        )
        .order_by(ClassificationResult.result_date.asc())
        .all()
    )

    return jsonify([r.to_dict() for r in pending]), 200


@vet_review_bp.route("/vet/reviews/<int:result_id>", methods=["POST"])
@jwt_required()
def submit_review(result_id):
    vet_id = get_jwt_identity()
    check = require_verified_vet(vet_id)
    if check is None:
        return jsonify({"error": "Only veterinarians can submit reviews"}), 403
    if check == "unverified":
        return jsonify({"error": "Your veterinary registration is pending verification. You cannot submit reviews yet."}), 403

    result = ClassificationResult.query.get(result_id)
    if not result:
        return jsonify({"error": "Classification result not found"}), 404

    data = request.get_json()
    if "decision" not in data or not data["decision"]:
        return jsonify({"error": "decision is required"}), 400

    new_review = VetReview(
        result_id=result_id,
        vet_id=vet_id,
        decision=data["decision"],
        comments=data.get("comments", "")
    )
    db.session.add(new_review)

    result.validation_status = data["decision"]

    db.session.commit()

    return jsonify({
        "message": "Review submitted successfully",
        "review": new_review.to_dict()
    }), 201


@vet_review_bp.route("/vet/reviews/<int:result_id>/details", methods=["GET"])
@jwt_required()
def get_case_details(result_id):
    from models import Image as ImageModel, Feedback

    vet_id = get_jwt_identity()
    if not require_vet(vet_id):
        return jsonify({"error": "Only veterinarians can access this route"}), 403

    result = ClassificationResult.query.get(result_id)
    if not result:
        return jsonify({"error": "Classification result not found"}), 404

    image = ImageModel.query.get(result.image_id)
    feedback_entries = Feedback.query.filter_by(result_id=result_id).all()
    review = VetReview.query.filter_by(result_id=result_id).order_by(VetReview.review_id.desc()).first()

    return jsonify({
        "result": result.to_dict(),
        "image": image.to_dict() if image else None,
        "feedback": [f.to_dict() for f in feedback_entries],
        "review": review.to_dict() if review else None,
    }), 200


@vet_review_bp.route("/vet/history", methods=["GET"])
@jwt_required()
def get_vet_case_history():
    vet_id = get_jwt_identity()
    if not require_vet(vet_id):
        return jsonify({"error": "Only veterinarians can access this route"}), 403

    reviews = VetReview.query.filter_by(vet_id=vet_id).order_by(VetReview.review_date.desc()).all()

    history = []
    for review in reviews:
        result = ClassificationResult.query.get(review.result_id)
        history.append({
            "review": review.to_dict(),
            "result": result.to_dict() if result else None,
        })

    return jsonify(history), 200