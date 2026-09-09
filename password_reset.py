import random
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from flask_mail import Message
from models import db, User, PasswordReset

password_reset_bp = Blueprint("password_reset", __name__)


def is_password_strong(password):
    import re
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


@password_reset_bp.route("/forgot-password", methods=["POST"])
def forgot_password():
    from app import mail, bcrypt

    data = request.get_json()
    email = data.get("email") if data else None

    if not email:
        return jsonify({"error": "Email is required"}), 400

    user = User.query.filter_by(email=email).first()

    if user:
        code = str(random.randint(100000, 999999))
        expires_at = datetime.utcnow() + timedelta(minutes=15)

        reset_entry = PasswordReset(
            user_id=user.user_id,
            reset_code=code,
            expires_at=expires_at,
            used=False,
        )
        db.session.add(reset_entry)
        db.session.commit()

        try:
            msg = Message(
                subject="Password Reset Code - Canine Skin App",
                recipients=[email],
                body=f"Your password reset code is: {code}\n\nThis code expires in 15 minutes.",
            )
            mail.send(msg)
        except Exception as e:
            print(f"[EMAIL ERROR] {e}")

    # Always return the same generic message, whether or not the email exists
    return jsonify({"message": "If that email is registered, a reset code has been sent."}), 200


@password_reset_bp.route("/reset-password", methods=["POST"])
def reset_password():
    from app import bcrypt

    data = request.get_json()
    email = data.get("email") if data else None
    reset_code = data.get("reset_code") if data else None
    new_password = data.get("new_password") if data else None

    if not email or not reset_code or not new_password:
        return jsonify({"error": "Email, reset code, and new password are required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "Invalid email or reset code"}), 400

    reset_entry = (
        PasswordReset.query.filter_by(user_id=user.user_id, reset_code=reset_code, used=False)
        .order_by(PasswordReset.id.desc())
        .first()
    )

    if not reset_entry or reset_entry.expires_at < datetime.utcnow():
        return jsonify({"error": "Invalid or expired reset code"}), 400

    if not is_password_strong(new_password):
        return jsonify({
            "error": "Password must be at least 8 characters and include an uppercase letter, a lowercase letter, a number, and a special character"
        }), 400

    user.password_hash = bcrypt.generate_password_hash(new_password).decode("utf-8")
    reset_entry.used = True
    db.session.commit()

    return jsonify({"message": "Password reset successfully"}), 200