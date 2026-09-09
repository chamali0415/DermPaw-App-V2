import os
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from PIL import Image as PILImage
from models import db, Dog, Image

dogs_bp = Blueprint("dogs", __name__)

UPLOAD_FOLDER = "uploads"
ALLOWED_FORMATS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB, per your SRS (BR7)
MIN_RESOLUTION = (512, 512)      # per your SRS (BR6)


@dogs_bp.route("/dogs", methods=["POST"])
@jwt_required()
def add_dog():
    user_id = get_jwt_identity()
    data = request.get_json()

    new_dog = Dog(
        user_id=user_id,
        age=data.get("age"),
        owner_type=data.get("owner_type")
    )
    db.session.add(new_dog)
    db.session.commit()

    return jsonify({"message": "Dog added successfully", "dog": new_dog.to_dict()}), 201


@dogs_bp.route("/dogs/<int:dog_id>/images", methods=["POST"])
@jwt_required()
def upload_image(dog_id):
    dog = Dog.query.get(dog_id)
    if not dog:
        return jsonify({"error": "Dog not found"}), 404

    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    filename = file.filename

    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_FORMATS:
        return jsonify({"error": "Only JPG or PNG files are allowed"}), 400

    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    file.seek(0)
    if file_size > MAX_FILE_SIZE:
        return jsonify({"error": "File exceeds maximum size of 5MB"}), 400

    try:
        img = PILImage.open(file)
        width, height = img.size
    except Exception:
        return jsonify({"error": "Invalid or corrupt image file"}), 400

    if width < MIN_RESOLUTION[0] or height < MIN_RESOLUTION[1]:
        return jsonify({"error": f"Image must be at least {MIN_RESOLUTION[0]}x{MIN_RESOLUTION[1]} pixels"}), 400

    save_path = os.path.join(UPLOAD_FOLDER, f"dog{dog_id}_{filename}")
    file.seek(0)
    file.save(save_path)

    new_image = Image(
        dog_id=dog_id,
        image_path=save_path,
        image_format=ext,
        image_size=file_size,
        resolution=f"{width}x{height}"
    )
    db.session.add(new_image)
    db.session.commit()

    return jsonify({"message": "Image uploaded successfully", "image": new_image.to_dict()}), 201