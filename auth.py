from flask import Blueprint, request, jsonify
from flask_bcrypt import Bcrypt
from flask_jwt_extended import create_access_token
from datetime import timedelta
from models import db, User, EmailVerification
from validators import normalize_sl_phone, PHONE_ERROR
import os
import secrets
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash

# ---- Email verification settings -------------------------------------------
CODE_EXPIRY_MINUTES = 10
RESEND_COOLDOWN_SECONDS = 60
MAX_CODE_ATTEMPTS = 5
# Set EMAIL_VERIFICATION_REQUIRED=false in .env to switch it off (e.g. if mail is down)
EMAIL_VERIFICATION_REQUIRED = os.getenv("EMAIL_VERIFICATION_REQUIRED", "true").lower() != "false"
EMAIL_PATTERN = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"

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


@auth_bp.route("/register/send-code", methods=["POST"])
def send_verification_code():
    """Step 1 of registration: e-mail a 4-digit code to the address."""
    from app import mail
    from flask_mail import Message

    data = request.get_json() or {}
    email = (data.get("email") or "").strip()

    if not re.match(EMAIL_PATTERN, email):
        return jsonify({"error": "Please enter a valid email address"}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "Email already registered"}), 409

    latest = (
        EmailVerification.query.filter_by(email=email)
        .order_by(EmailVerification.id.desc())
        .first()
    )
    if latest:
        waited = (datetime.utcnow() - latest.created_at).total_seconds()
        if waited < RESEND_COOLDOWN_SECONDS:
            wait_left = int(RESEND_COOLDOWN_SECONDS - waited) + 1
            return jsonify({
                "error": f"Please wait {wait_left} seconds before requesting a new code",
                "retry_after": wait_left,
            }), 429

    code = f"{secrets.randbelow(10000):04d}"   # always 4 digits, e.g. 0427

    # Only the newest code is valid
    EmailVerification.query.filter_by(email=email).delete(synchronize_session=False)
    entry = EmailVerification(
        email=email,
        code_hash=generate_password_hash(code),
        expires_at=datetime.utcnow() + timedelta(minutes=CODE_EXPIRY_MINUTES),
    )
    db.session.add(entry)
    db.session.commit()

    try:
        msg = Message(
            subject="Your DermPaw verification code",
            recipients=[email],
            body=(
                f"Welcome to DermPaw!\n\n"
                f"Your verification code is: {code}\n\n"
                f"Enter this code in the app to finish creating your account. "
                f"It expires in {CODE_EXPIRY_MINUTES} minutes.\n\n"
                f"If you did not try to register, you can ignore this email."
            ),
        )
        mail.send(msg)
    except Exception as e:
        print(f"[EMAIL ERROR] verification code to {email}: {e}")
        db.session.delete(entry)
        db.session.commit()
        return jsonify({"error": "Could not send the verification email. Please check the address and try again."}), 500

    return jsonify({
        "message": f"A 4-digit code was sent to {email}",
        "expires_in_minutes": CODE_EXPIRY_MINUTES,
    }), 200


def _check_verification_code(email, code):
    """Returns None if the code is correct, otherwise an error message."""
    code = (code or "").strip()
    if not re.fullmatch(r"\d{4}", code):
        return "Please enter the 4-digit code sent to your email"
    entry = (
        EmailVerification.query.filter_by(email=email)
        .order_by(EmailVerification.id.desc())
        .first()
    )
    if not entry:
        return "Please request a verification code first"
    if entry.expires_at < datetime.utcnow():
        return "This code has expired. Please request a new one"
    if entry.attempts >= MAX_CODE_ATTEMPTS:
        return "Too many wrong attempts. Please request a new code"
    if not check_password_hash(entry.code_hash, code):
        entry.attempts += 1
        db.session.commit()
        left = MAX_CODE_ATTEMPTS - entry.attempts
        return f"Incorrect code. {left} attempt(s) left" if left > 0 else "Too many wrong attempts. Please request a new code"
    return None


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

    phone_number = None
    raw_phone = (data.get("phone_number") or "").strip()
    if raw_phone:
        phone_number = normalize_sl_phone(raw_phone)
        if not phone_number:
            return jsonify({"error": PHONE_ERROR}), 400
        existing_phone = User.query.filter_by(phone_number=phone_number).first()
        if existing_phone:
            return jsonify({"error": "Phone number already registered"}), 409

    if not is_password_strong(data["password"]):
        return jsonify({
            "error": "Password must be at least 8 characters and include an uppercase letter, a lowercase letter, a number, and a special character"
        }), 400

    if EMAIL_VERIFICATION_REQUIRED:
        code_error = _check_verification_code(data["email"].strip(), data.get("verification_code"))
        if code_error:
            return jsonify({"error": code_error, "code_error": True}), 400

    is_vet = data.get("role") == "vet"
    vet_licence_no = data.get("vet_licence_no")

    if is_vet and not vet_licence_no:
        return jsonify({"error": "Veterinary licence number is required for vet accounts"}), 400

    password_hash = bcrypt.generate_password_hash(data["password"]).decode("utf-8")

    new_user = User(
        name=data["name"],
        email=data["email"],
        phone_number=phone_number,
        password_hash=password_hash,
        consent_status=data.get("consent_status", False),
        is_vet=is_vet,
        vet_licence_no=vet_licence_no if is_vet else None,
        is_verified=not is_vet,   # vets start unverified until an admin approves them
    )
    db.session.add(new_user)
    # The code has been used - remove it
    EmailVerification.query.filter_by(email=data["email"].strip()).delete(synchronize_session=False)
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