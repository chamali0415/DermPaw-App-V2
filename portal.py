"""
DermPaw Admin Portal (web)
Server-rendered admin pages, served by the same Flask app as the mobile API.
Open in a laptop browser: http://<server-ip>:5000/portal/login
"""
import csv
import io
import secrets
from datetime import timedelta
from functools import wraps

from flask import (Blueprint, render_template, request, redirect, url_for,
                   session, flash, abort, Response)
from sqlalchemy import func

from models import (db, User, Dog, Image, ClassificationResult,
                    VetReview, AppReview)
from auth import bcrypt

portal_bp = Blueprint("portal", __name__, url_prefix="/portal")

ADMIN_SESSION_MINUTES = 15


# ---------------------------------------------------------------- helpers

def current_admin():
    """Return the logged-in admin User, or None."""
    admin_id = session.get("admin_id")
    if not admin_id:
        return None
    user = db.session.get(User, admin_id)
    if not user or not user.is_admin or not user.is_active:
        session.clear()
        return None
    return user


def admin_required(view):
    """Protect a portal page: only a logged-in, active admin can open it."""
    @wraps(view)
    def wrapper(*args, **kwargs):
        if current_admin() is None:
            flash("Please log in as an administrator.", "error")
            return redirect(url_for("portal.login"))
        return view(*args, **kwargs)
    return wrapper


@portal_bp.before_request
def _before_portal_request():
    # Portal sessions expire after 15 minutes of inactivity
    session.permanent = True
    # Every POST form must carry the session's CSRF token
    if request.method == "POST":
        token = session.get("csrf_token")
        if not token or token != request.form.get("csrf_token"):
            abort(400, "Invalid or missing CSRF token")


@portal_bp.context_processor
def _inject_globals():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_hex(16)
    return {"csrf_token": session["csrf_token"], "admin": current_admin()}


# ---------------------------------------------------------------- login

@portal_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form.get("email", "").strip()
        password = request.form.get("password", "")
        user = User.query.filter_by(email=email).first()

        if (not user or not user.is_admin or not user.is_active
                or not bcrypt.check_password_hash(user.password_hash, password)):
            flash("Invalid admin credentials.", "error")
            return render_template("portal/login.html"), 401

        csrf = session.get("csrf_token")
        session.clear()
        session["admin_id"] = user.user_id
        session["csrf_token"] = csrf or secrets.token_hex(16)
        return redirect(url_for("portal.dashboard"))

    return render_template("portal/login.html")


@portal_bp.route("/logout", methods=["POST"])
def logout():
    session.clear()
    flash("You have been logged out.", "success")
    return redirect(url_for("portal.login"))


# ---------------------------------------------------------------- dashboard

@portal_bp.route("/")
@admin_required
def dashboard():
    stats = {
        "owners": User.query.filter_by(is_vet=False, is_admin=False).count(),
        "vets": User.query.filter_by(is_vet=True, is_verified=True).count(),
        "pending_vets": User.query.filter_by(is_vet=True, is_verified=False, is_active=True).count(),
        "dogs": Dog.query.count(),
        "classifications": ClassificationResult.query.count(),
        "reviewed": VetReview.query.count(),
        "avg_rating": db.session.query(func.avg(AppReview.rating)).scalar(),
    }

    # Model performance from vet reviews:
    # approved = vet chose the same label the model predicted
    rows = (
        db.session.query(ClassificationResult.predicted_disease, VetReview.decision)
        .join(VetReview, VetReview.result_id == ClassificationResult.result_id)
        .all()
    )
    per_class = {}
    overrides = {}
    for predicted, decision in rows:
        c = per_class.setdefault(predicted, {"reviewed": 0, "approved": 0})
        c["reviewed"] += 1
        if decision == predicted:
            c["approved"] += 1
        else:
            key = (predicted, decision)
            overrides[key] = overrides.get(key, 0) + 1

    for c in per_class.values():
        c["rate"] = round(100 * c["approved"] / c["reviewed"], 1)

    total_reviewed = sum(c["reviewed"] for c in per_class.values())
    total_approved = sum(c["approved"] for c in per_class.values())
    overall = round(100 * total_approved / total_reviewed, 1) if total_reviewed else None

    top_overrides = sorted(overrides.items(), key=lambda kv: kv[1], reverse=True)[:5]

    return render_template(
        "portal/dashboard.html",
        stats=stats,
        per_class=sorted(per_class.items()),
        overall=overall,
        total_reviewed=total_reviewed,
        top_overrides=top_overrides,
    )


# ---------------------------------------------------------------- vets

@portal_bp.route("/vets")
@admin_required
def vets():
    pending = (User.query.filter_by(is_vet=True, is_verified=False, is_active=True)
               .order_by(User.created_at.asc()).all())
    verified = (User.query.filter_by(is_vet=True, is_verified=True)
                .order_by(User.name.asc()).all())
    return render_template("portal/vets.html", pending=pending, verified=verified)


@portal_bp.route("/vets/<int:user_id>/verify", methods=["POST"])
@admin_required
def verify_vet(user_id):
    user = db.session.get(User, user_id)
    if not user or not user.is_vet:
        abort(404)
    user.is_verified = True
    user.is_active = True
    db.session.commit()
    flash(f"{user.name} has been verified as a veterinarian.", "success")
    return redirect(url_for("portal.vets"))


@portal_bp.route("/vets/<int:user_id>/reject", methods=["POST"])
@admin_required
def reject_vet(user_id):
    user = db.session.get(User, user_id)
    if not user or not user.is_vet:
        abort(404)
    user.is_verified = False
    user.is_active = False
    db.session.commit()
    flash(f"{user.name}'s vet registration was rejected and the account deactivated.", "success")
    return redirect(url_for("portal.vets"))


# ---------------------------------------------------------------- users

@portal_bp.route("/users")
@admin_required
def users():
    q = request.args.get("q", "").strip()
    query = User.query
    if q:
        like = f"%{q}%"
        query = query.filter((User.name.like(like)) | (User.email.like(like)))
    all_users = query.order_by(User.created_at.desc()).all()
    return render_template("portal/users.html", users=all_users, q=q)


@portal_bp.route("/users/<int:user_id>/toggle-active", methods=["POST"])
@admin_required
def toggle_active(user_id):
    user = db.session.get(User, user_id)
    if not user:
        abort(404)
    if user.user_id == current_admin().user_id:
        flash("You cannot deactivate your own admin account.", "error")
        return redirect(url_for("portal.users"))
    user.is_active = not user.is_active
    db.session.commit()
    state = "reactivated" if user.is_active else "deactivated"
    flash(f"{user.name}'s account was {state}.", "success")
    return redirect(url_for("portal.users", q=request.form.get("q", "")))


# ---------------------------------------------------------------- app reviews

@portal_bp.route("/reviews")
@admin_required
def reviews():
    rows = (
        db.session.query(AppReview, User)
        .join(User, AppReview.user_id == User.user_id)
        .order_by(AppReview.updated_at.desc())
        .all()
    )
    return render_template("portal/reviews.html", rows=rows)


@portal_bp.route("/reviews/<int:review_id>/toggle-hidden", methods=["POST"])
@admin_required
def toggle_hidden(review_id):
    review = db.session.get(AppReview, review_id)
    if not review:
        abort(404)
    review.is_hidden = not review.is_hidden
    db.session.commit()
    flash("Review hidden from the app." if review.is_hidden else "Review is visible again.", "success")
    return redirect(url_for("portal.reviews"))


# ---------------------------------------------------------------- export

@portal_bp.route("/export/vet-confirmed.csv")
@admin_required
def export_vet_confirmed():
    """Vet-confirmed labels, ready to build a real dataset for retraining."""
    rows = (
        db.session.query(VetReview, ClassificationResult, Image)
        .join(ClassificationResult, VetReview.result_id == ClassificationResult.result_id)
        .join(Image, ClassificationResult.image_id == Image.image_id)
        .order_by(VetReview.review_date.asc())
        .all()
    )
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["image_id", "image_path", "model_prediction", "confidence",
                     "vet_label", "vet_agreed", "review_date"])
    for review, result, image in rows:
        writer.writerow([
            image.image_id, image.image_path, result.predicted_disease,
            result.confidence_score, review.decision,
            review.decision == result.predicted_disease,
            review.review_date.isoformat() if review.review_date else "",
        ])
    return Response(
        out.getvalue(), mimetype="text/csv",
        headers={"Content-Disposition": "attachment; filename=vet_confirmed_labels.csv"},
    )


def configure_portal(app):
    """Call once from app.py after creating the app."""
    app.permanent_session_lifetime = timedelta(minutes=ADMIN_SESSION_MINUTES)
    app.config.setdefault("SESSION_COOKIE_HTTPONLY", True)
    app.config.setdefault("SESSION_COOKIE_SAMESITE", "Lax")
    app.register_blueprint(portal_bp)
