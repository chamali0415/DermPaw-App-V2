from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, AppReview, User

app_review_bp = Blueprint("app_review", __name__)


@app_review_bp.route("/app-review", methods=["GET"])
@jwt_required()
def get_my_app_review():
    user_id = get_jwt_identity()
    review = AppReview.query.filter_by(user_id=user_id).first()
    if not review:
        return jsonify({"review": None}), 200
    return jsonify({"review": review.to_dict()}), 200


@app_review_bp.route("/app-review", methods=["POST"])
@jwt_required()
def submit_app_review():
    user_id = get_jwt_identity()
    data = request.get_json()

    rating = data.get("rating")
    comment = data.get("comment", "")

    if rating is None or not isinstance(rating, int) or rating < 1 or rating > 5:
        return jsonify({"error": "rating must be an integer from 1 to 5"}), 400

    existing = AppReview.query.filter_by(user_id=user_id).first()
    if existing:
        existing.rating = rating
        existing.comment = comment
        db.session.commit()
        return jsonify({"message": "Review updated", "review": existing.to_dict()}), 200
    else:
        new_review = AppReview(user_id=user_id, rating=rating, comment=comment)
        db.session.add(new_review)
        db.session.commit()
        return jsonify({"message": "Review submitted", "review": new_review.to_dict()}), 201


@app_review_bp.route("/app-reviews", methods=["GET"])
@jwt_required()
def list_app_reviews():
    reviews = (
        db.session.query(AppReview, User)
        .join(User, AppReview.user_id == User.user_id)
        .filter(AppReview.is_hidden == False)
        .order_by(AppReview.updated_at.desc())
        .all()
    )

    review_list = []
    total_rating = 0
    for review, user in reviews:
        review_list.append({
            "review_id": review.review_id,
            "rating": review.rating,
            "comment": review.comment,
            "updated_at": review.updated_at.isoformat() if review.updated_at else None,
            "reviewer_name": user.name,
        })
        total_rating += review.rating

    average_rating = round(total_rating / len(review_list), 2) if review_list else 0

    return jsonify({
        "average_rating": average_rating,
        "total_reviews": len(review_list),
        "reviews": review_list,
    }), 200