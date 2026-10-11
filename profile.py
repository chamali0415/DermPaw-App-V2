from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Dog, Image, ClassificationResult, Feedback, VetReview
from flask_bcrypt import check_password_hash
from validators import normalize_sl_phone, PHONE_ERROR

profile_bp = Blueprint("profile", __name__)


@profile_bp.route("/profile", methods=["GET"])
@jwt_required()
def get_profile():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user.to_dict()), 200


@profile_bp.route("/profile", methods=["PUT"])
@jwt_required()
def update_profile():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json()
    if "name" in data:
        user.name = data["name"]
    if "phone_number" in data:
        raw_phone = (data["phone_number"] or "").strip()
        if raw_phone == "":
            user.phone_number = None
        else:
            phone = normalize_sl_phone(raw_phone)
            if not phone:
                return jsonify({"error": PHONE_ERROR}), 400
            taken = User.query.filter(User.phone_number == phone, User.user_id != user.user_id).first()
            if taken:
                return jsonify({"error": "Phone number already registered"}), 409
            user.phone_number = phone

    db.session.commit()
    return jsonify({"message": "Profile updated successfully", "user": user.to_dict()}), 200


@profile_bp.route("/profile", methods=["DELETE"])
@jwt_required()
def delete_profile():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json()
    password = data.get("password") if data else None

    if not password or not check_password_hash(user.password_hash, password):
        return jsonify({"error": "Incorrect password"}), 401

    # Find this user's dogs -> images -> classification results
    dog_ids = [d.dog_id for d in Dog.query.filter_by(user_id=user_id).all()]
    image_ids = [i.image_id for i in Image.query.filter(Image.dog_id.in_(dog_ids)).all()] if dog_ids else []
    result_ids = [r.result_id for r in ClassificationResult.query.filter(ClassificationResult.image_id.in_(image_ids)).all()] if image_ids else []

    # Delete deepest-dependent rows first
    if result_ids:
        VetReview.query.filter(VetReview.result_id.in_(result_ids)).delete(synchronize_session=False)
        Feedback.query.filter(Feedback.result_id.in_(result_ids)).delete(synchronize_session=False)
        ClassificationResult.query.filter(ClassificationResult.result_id.in_(result_ids)).delete(synchronize_session=False)

    if image_ids:
        Image.query.filter(Image.image_id.in_(image_ids)).delete(synchronize_session=False)

    if dog_ids:
        Dog.query.filter(Dog.dog_id.in_(dog_ids)).delete(synchronize_session=False)

    # If this account is a vet, also remove their reviews/feedback on OTHER users' cases
    VetReview.query.filter_by(vet_id=user_id).delete(synchronize_session=False)
    Feedback.query.filter_by(user_id=user_id).delete(synchronize_session=False)

    db.session.delete(user)
    db.session.commit()

    return jsonify({"message": "Account deleted successfully"}), 200