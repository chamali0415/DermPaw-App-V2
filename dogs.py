import os
import uuid
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from PIL import Image as PILImage, ImageOps, UnidentifiedImageError
from models import db, Dog, Image

dogs_bp = Blueprint("dogs", __name__)

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# We check the REAL format by opening the file, not by its extension.
# Photos saved from the internet are often .webp, have no extension, or have
# names like "image(3).jpg?size=large" - those used to be rejected.
ACCEPTED_PIL_FORMATS = {"JPEG", "PNG", "WEBP", "BMP", "GIF", "MPO"}
MAX_FILE_SIZE = 10 * 1024 * 1024   # 10 MB - matches the limit shown in the app
MIN_SIDE = 150                      # only reject tiny thumbnails/icons
MAX_SIDE = 2048                     # very large photos are downscaled on save


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

    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    file.seek(0)
    if file_size == 0:
        return jsonify({"error": "The selected file is empty. Please choose another photo."}), 400
    if file_size > MAX_FILE_SIZE:
        return jsonify({"error": "This photo is larger than 10MB. Please choose a smaller photo."}), 400

    try:
        img = PILImage.open(file)
        original_format = img.format or "UNKNOWN"
        img.load()
    except (UnidentifiedImageError, OSError):
        return jsonify({"error": "This file is not a supported image. Please upload a JPG or PNG photo."}), 400

    if original_format not in ACCEPTED_PIL_FORMATS:
        return jsonify({"error": f"{original_format} images are not supported. Please upload a JPG or PNG photo."}), 400

    # Respect phone camera rotation, flatten transparency, force 3-channel RGB
    img = ImageOps.exif_transpose(img)
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        background = PILImage.new("RGB", img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[-1])
        img = background
    else:
        img = img.convert("RGB")

    width, height = img.size
    if min(width, height) < MIN_SIDE:
        return jsonify({
            "error": f"This photo is too small ({width}x{height}). Please use a photo at least {MIN_SIDE}x{MIN_SIDE} pixels."
        }), 400

    if max(width, height) > MAX_SIDE:
        img.thumbnail((MAX_SIDE, MAX_SIDE))
        width, height = img.size

    # Unique, safe filename - never trust the uploaded name
    save_path = os.path.join(UPLOAD_FOLDER, f"dog{dog_id}_{uuid.uuid4().hex}.jpg")
    img.save(save_path, "JPEG", quality=92)

    new_image = Image(
        dog_id=dog_id,
        image_path=save_path,
        image_format="jpg",
        image_size=os.path.getsize(save_path),
        resolution=f"{width}x{height}"
    )
    db.session.add(new_image)
    db.session.commit()

    return jsonify({"message": "Image uploaded successfully", "image": new_image.to_dict()}), 201
