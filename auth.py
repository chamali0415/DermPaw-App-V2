from flask import Blueprint, request, jsonify
from flask_bcrypt import Bcrypt
from flask_jwt_extended import create_access_token
from datetime import timedelta
from models import db, User

import re

def is_password_strong(password):
    if len(password) < 8:
        return False
    if not re.search(r"[A-Z]", password):
        return False
    if not re.search(r"[a-z]", password):
        return False
    if not re.search(r"[0-9]", password):
        return False
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False
    return True

auth_bp = Blueprint("auth", __name__)
bcrypt = Bcrypt()


@auth_bp.route("/register", methods=["POST"])
def register():
    data = request.get_json()

    required_fields = ["name", "email", "password"]
    for field in required_fields:
        if field not in data or not data[field]:
            return jsonify({"error": f"Missing field: {field}"}), 400

    existing_user = User.query.filter_by(email=data["email"]).first()
    if existing_user:
        return jsonify({"error": "Email already registered"}), 409

    phone_number = data.get("phone_number")
    if phone_number:
        existing_phone = User.query.filter_by(phone_number=phone_number).first()
        if existing_phone:
            return jsonify({"error": "Phone number already registered"}), 409

    if not is_password_strong(data["password"]):
        return jsonify({
            "error": "Password must be at least 8 characters and include an uppercase letter, a lowercase letter, a number, and a special character"
        }), 400

    is_vet = data.get("role") == "vet"
    vet_licence_no = data.get("vet_licence_no")

    if is_vet and not vet_licence_no:
        return jsonify({"error": "Veterinary licence number is required for vet accounts"}), 400

    password_hash = bcrypt.generate_password_hash(data["password"]).decode("utf-8")

    new_user = User(
        name=data["name"],
        email=data["email"],
        phone_number=data.get("phone_number"),
        password_hash=password_hash,
        consent_status=data.get("consent_status", False),
        is_vet=is_vet,
        vet_licence_no=vet_licence_no if is_vet else None,
        is_verified=not is_vet,   # vets start unverified until an admin approves them
    )
    db.session.add(new_user)
    db.session.commit()

    expiry = timedelta(minutes=15) if new_user.is_vet else timedelta(minutes=30)
    access_token = create_access_token(identity=str(new_user.user_id), expires_delta=expiry)

    return jsonify({
        "message": "User registered successfully",
        "access_token": access_token,
        "user": new_user.to_dict(),
    }), 201

@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json()

    if "email" not in data or "password" not in data:
        return jsonify({"error": "Email and password are required"}), 400

    user = User.query.filter_by(email=data["email"]).first()
    if not user or not bcrypt.check_password_hash(user.password_hash, data["password"]):
        return jsonify({"error": "Invalid email or password"}), 401

    if not user.is_active:
        return jsonify({"error": "This account has been deactivated. Please contact the DermPaw administrator."}), 403

    expiry = timedelta(minutes=15) if (user.is_vet or user.is_admin) else timedelta(minutes=30)
    access_token = create_access_token(identity=str(user.user_id), expires_delta=expiry)
    return jsonify({"message": "Login successful", "access_token": access_token, "user": user.to_dict()}), 200