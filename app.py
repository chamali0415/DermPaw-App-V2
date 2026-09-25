import os
from flask import Flask
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager
from flask_mail import Mail
from datetime import timedelta
from dotenv import load_dotenv

from models import db
from auth import auth_bp
from profile import profile_bp
from dogs import dogs_bp
from classify import classify_bp
from feedback import feedback_bp
from vet_review import vet_review_bp
from history import history_bp
from password_reset import password_reset_bp
from app_review import app_review_bp
from admin import admin_bp
from portal import configure_portal

load_dotenv()

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = (
    f"mysql+pymysql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
    f"@{os.getenv('DB_HOST')}/{os.getenv('DB_NAME')}"
)
app.config["JWT_SECRET_KEY"] = os.getenv("JWT_SECRET_KEY")
app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY")  # signs admin portal session cookies
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(minutes=30)
app.config["MAIL_SERVER"] = "smtp.gmail.com"
app.config["MAIL_PORT"] = 587
app.config["MAIL_USE_TLS"] = True
app.config["MAIL_USERNAME"] = os.getenv("MAIL_USERNAME")
app.config["MAIL_PASSWORD"] = os.getenv("MAIL_PASSWORD")
app.config["MAIL_DEFAULT_SENDER"] = os.getenv("MAIL_USERNAME")

db.init_app(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)
mail = Mail(app)

app.register_blueprint(auth_bp)
app.register_blueprint(profile_bp)
app.register_blueprint(dogs_bp)
app.register_blueprint(classify_bp)
app.register_blueprint(feedback_bp)
app.register_blueprint(vet_review_bp)
app.register_blueprint(history_bp)
app.register_blueprint(password_reset_bp)
app.register_blueprint(app_review_bp)
app.register_blueprint(admin_bp)
configure_portal(app)

@app.route("/health")
def health():
    return {"status": "ok"}

@app.route("/routes")
def list_routes():
    output = []
    for rule in app.url_map.iter_rules():
        output.append(f"{rule.methods} {rule.rule}")
    return "<br>".join(sorted(output))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

