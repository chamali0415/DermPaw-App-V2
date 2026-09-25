from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User

admin_bp = Blueprint("admin", __name__)


def require_admin(user_id):
    user = User.query.get(user_id)
    if not user or not user.is_admin:
        return False
    return True


@admin_bp.route("/admin/pending-vets", methods=["GET"])
@jwt_required()
def list_pending_vets():
    admin_id = get_jwt_identity()
    if not require_admin(admin_id):
        return jsonify({"error": "Admin access only"}), 403

    pending = User.query.filter_by(is_vet=True, is_verified=False, is_active=True).all()
    return jsonify([u.to_dict() for u in pending]), 200


@admin_bp.route("/admin/vets/<int:user_id>/verify", methods=["POST"])
@jwt_required()
def verify_vet(user_id):
    admin_id = get_jwt_identity()
    if not require_admin(admin_id):
        return jsonify({"error": "Admin access only"}), 403

    user = User.query.get(user_id)
    if not user or not user.is_vet:
        return jsonify({"error": "Vet account not found"}), 404

    user.is_verified = True
    db.session.commit()

    return jsonify({"message": "Vet verified successfully", "user": user.to_dict()}), 200