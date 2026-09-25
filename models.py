from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = "users"

    user_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    phone_number = db.Column(db.String(20))
    password_hash = db.Column(db.String(255), nullable=False)
    consent_status = db.Column(db.Boolean, default=False)
    is_vet = db.Column(db.Boolean, default=False)
    vet_licence_no = db.Column(db.String(50), nullable=True)
    is_verified = db.Column(db.Boolean, default=True)
    is_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "user_id": self.user_id,
            "name": self.name,
            "email": self.email,
            "phone_number": self.phone_number,
            "is_vet": self.is_vet,
            "vet_licence_no": self.vet_licence_no,
            "is_verified": self.is_verified,
            "is_admin": self.is_admin,
            "is_active": self.is_active,
        }
    
class Dog(db.Model):
    __tablename__ = "dogs"

    dog_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False)
    age = db.Column(db.Integer)
    owner_type = db.Column(db.String(50))

    def to_dict(self):
        return {
            "dog_id": self.dog_id,
            "user_id": self.user_id,
            "age": self.age,
            "owner_type": self.owner_type
        }


class Image(db.Model):
    __tablename__ = "images"

    image_id = db.Column(db.Integer, primary_key=True)
    dog_id = db.Column(db.Integer, db.ForeignKey("dogs.dog_id"), nullable=False)
    image_path = db.Column(db.String(255), nullable=False)
    image_format = db.Column(db.String(10))
    image_size = db.Column(db.Integer)
    resolution = db.Column(db.String(20))
    upload_date = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "image_id": self.image_id,
            "dog_id": self.dog_id,
            "image_path": self.image_path,
            "image_format": self.image_format,
            "image_size": self.image_size,
            "resolution": self.resolution
        }

class ClassificationResult(db.Model):
    __tablename__ = "classification_results"

    result_id = db.Column(db.Integer, primary_key=True)
    image_id = db.Column(db.Integer, db.ForeignKey("images.image_id"), nullable=False)
    predicted_disease = db.Column(db.String(100))
    confidence_score = db.Column(db.Float)
    result_date = db.Column(db.DateTime, default=datetime.utcnow)
    review_requested = db.Column(db.Boolean, default=False)
    validation_status = db.Column(db.String(20), default="Pending")

    def to_dict(self):
        return {
            "result_id": self.result_id,
            "image_id": self.image_id,
            "predicted_disease": self.predicted_disease,
            "confidence_score": self.confidence_score,
            "result_date": self.result_date.isoformat() if self.result_date else None,
            "review_requested": self.review_requested,
            "validation_status": self.validation_status,
        }

class Feedback(db.Model):
    __tablename__ = "feedback"

    feedback_id = db.Column(db.Integer, primary_key=True)
    result_id = db.Column(db.Integer, db.ForeignKey("classification_results.result_id"), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False)
    feedback_text = db.Column(db.Text)
    feedback_date = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "feedback_id": self.feedback_id,
            "result_id": self.result_id,
            "user_id": self.user_id,
            "feedback_text": self.feedback_text
        }

class VetReview(db.Model):
    __tablename__ = "vet_reviews"

    review_id = db.Column(db.Integer, primary_key=True)
    result_id = db.Column(db.Integer, db.ForeignKey("classification_results.result_id"), nullable=False)
    vet_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False)
    decision = db.Column(db.String(50))
    comments = db.Column(db.Text)
    review_date = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "review_id": self.review_id,
            "result_id": self.result_id,
            "vet_id": self.vet_id,
            "decision": self.decision,
            "comments": self.comments
        }

class AppReview(db.Model):
    __tablename__ = "app_reviews"

    review_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), unique=True, nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text, nullable=True)
    is_hidden = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "review_id": self.review_id,
            "user_id": self.user_id,
            "rating": self.rating,
            "comment": self.comment,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

class PasswordReset(db.Model):
    __tablename__ = "password_resets"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False)
    reset_code = db.Column(db.String(6), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    used = db.Column(db.Boolean, default=False)