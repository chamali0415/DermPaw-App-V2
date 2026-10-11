import os
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Dog, Image, ClassificationResult, VetReview, Feedback

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


# ---------------------------------------------------------------- delete cases

def _owned_results_query(user_id):
    """All classification results that belong to this owner's dogs."""
    return (
        ClassificationResult.query
        .join(Image, ClassificationResult.image_id == Image.image_id)
        .join(Dog, Image.dog_id == Dog.dog_id)
        .filter(Dog.user_id == int(user_id))
    )


def _delete_results(results):
    """Delete results plus their vet reviews, feedback, image rows/files and
    any dog record left with no images. Returns how many cases were deleted."""
    if not results:
        return 0
    result_ids = [r.result_id for r in results]
    image_ids = list({r.image_id for r in results})

    VetReview.query.filter(VetReview.result_id.in_(result_ids)).delete(synchronize_session=False)
    Feedback.query.filter(Feedback.result_id.in_(result_ids)).delete(synchronize_session=False)
    ClassificationResult.query.filter(ClassificationResult.result_id.in_(result_ids)).delete(synchronize_session=False)

    # Only remove an image if no other result still uses it
    still_used = {
        r.image_id for r in ClassificationResult.query.filter(ClassificationResult.image_id.in_(image_ids)).all()
    }
    images = Image.query.filter(Image.image_id.in_(image_ids)).all()
    dog_ids = set()
    for img in images:
        if img.image_id in still_used:
            continue
        dog_ids.add(img.dog_id)
        try:
            if img.image_path and os.path.exists(img.image_path):
                os.remove(img.image_path)
        except OSError as e:
            print(f"[history] could not remove file {img.image_path}: {e}")
        db.session.delete(img)
    db.session.flush()

    # Each scan creates its own dog record; remove those left empty
    for dog_id in dog_ids:
        if Image.query.filter_by(dog_id=dog_id).count() == 0:
            dog = Dog.query.get(dog_id)
            if dog:
                db.session.delete(dog)

    db.session.commit()
    return len(result_ids)


@history_bp.route("/history/<int:result_id>", methods=["DELETE"])
@jwt_required()
def delete_case(result_id):
    user_id = get_jwt_identity()
    result = _owned_results_query(user_id).filter(ClassificationResult.result_id == result_id).first()
    if not result:
        return jsonify({"error": "Case not found"}), 404
    _delete_results([result])
    return jsonify({"message": "Case deleted", "deleted": 1}), 200


@history_bp.route("/history", methods=["DELETE"])
@jwt_required()
def delete_all_cases():
    user_id = get_jwt_identity()
    results = _owned_results_query(user_id).all()
    count = _delete_results(results)
    return jsonify({"message": f"{count} case(s) deleted", "deleted": count}), 200

