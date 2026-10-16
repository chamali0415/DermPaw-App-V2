import os
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify, send_file
from PIL import Image as PILImage, ImageOps, UnidentifiedImageError
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

    _remove_picture_file(user)
    db.session.delete(user)
    db.session.commit()

    return jsonify({"message": "Account deleted successfully"}), 200


# ------------------------------------------------------------ profile picture
PROFILE_FOLDER = os.path.join("uploads", "profiles")
MAX_PICTURE_SIZE = 10 * 1024 * 1024  # 10 MB
PICTURE_SIDE = 512                   # stored as a 512x512 square JPEG


def _remove_picture_file(user):
    if user.profile_image_path and os.path.exists(user.profile_image_path):
        try:
            os.remove(user.profile_image_path)
        except OSError as e:
            print(f"[profile] could not remove {user.profile_image_path}: {e}")


@profile_bp.route("/profile/picture", methods=["POST"])
@jwt_required()
def upload_profile_picture():
    user = User.query.get(get_jwt_identity())
    if not user:
        return jsonify({"error": "User not found"}), 404
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    file.seek(0, os.SEEK_END)
    size = file.tell()
    file.seek(0)
    if size == 0 or size > MAX_PICTURE_SIZE:
        return jsonify({"error": "Please choose a photo smaller than 10MB"}), 400

    try:
        img = PILImage.open(file)
        img.load()
    except (UnidentifiedImageError, OSError):
        return jsonify({"error": "This file is not a supported image"}), 400

    # Square crop from the centre, fixed size, always JPEG
    img = ImageOps.exif_transpose(img).convert("RGB")
    img = ImageOps.fit(img, (PICTURE_SIDE, PICTURE_SIDE))

    os.makedirs(PROFILE_FOLDER, exist_ok=True)
    path = os.path.join(PROFILE_FOLDER, f"user{user.user_id}_{uuid.uuid4().hex}.jpg")
    img.save(path, "JPEG", quality=90)

    _remove_picture_file(user)  # delete the old picture file
    user.profile_image_path = path
    user.profile_image_updated = datetime.utcnow()
    db.session.commit()
    return jsonify({"message": "Profile picture updated", "user": user.to_dict()}), 200


@profile_bp.route("/profile/picture", methods=["DELETE"])
@jwt_required()
def delete_profile_picture():
    user = User.query.get(get_jwt_identity())
    if not user:
        return jsonify({"error": "User not found"}), 404
    _remove_picture_file(user)
    user.profile_image_path = None
    user.profile_image_updated = datetime.utcnow()
    db.session.commit()
    return jsonify({"message": "Profile picture removed", "user": user.to_dict()}), 200


@profile_bp.route("/users/<int:user_id>/picture", methods=["GET"])
@jwt_required()
def get_profile_picture(user_id):
    user = User.query.get(user_id)
    if not user or not user.profile_image_path or not os.path.exists(user.profile_image_path):
        return jsonify({"error": "No profile picture"}), 404
    return send_file(user.profile_image_path, mimetype="image/jpeg")

