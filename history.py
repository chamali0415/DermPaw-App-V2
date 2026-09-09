from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Dog, Image, ClassificationResult, VetReview

history_bp = Blueprint("history", __name__)


@history_bp.route("/history", methods=["GET"])
@jwt_required()
def get_history():
    user_id = get_jwt_identity()

    dogs = Dog.query.filter_by(user_id=user_id).all()
    dog_ids = [dog.dog_id for dog in dogs]

    images = Image.query.filter(Image.dog_id.in_(dog_ids)).all()
    image_ids = [img.image_id for img in images]

    results = ClassificationResult.query.filter(
        ClassificationResult.image_id.in_(image_ids)
    ).order_by(ClassificationResult.result_date.desc()).all()

    history = []
    for result in results:
        item = result.to_dict()

        # Attach the most recent vet review for this result, if any
        review = (
            VetReview.query
            .filter_by(result_id=result.result_id)
            .order_by(VetReview.review_id.desc())
            .first()
        )
        item["vet_review"] = review.to_dict() if review else None

        history.append(item)

    return jsonify(history), 200