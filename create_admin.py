"""
Create (or promote) a DermPaw administrator account.

Run from the backend folder with the venv active:
    python create_admin.py

Admins can NEVER be created through the app's /register route.
This script is the only way to make one.
"""
import getpass
import sys

from app import app
from models import db, User
from auth import bcrypt, is_password_strong


def main():
    print("=== Create DermPaw admin account ===")
    email = input("Admin email: ").strip()
    if not email:
        sys.exit("Email is required.")

    with app.app_context():
        existing = User.query.filter_by(email=email).first()

        if existing:
            answer = input(f"{existing.name} <{email}> already exists. Make this user an admin? (y/n): ")
            if answer.strip().lower() != "y":
                sys.exit("Cancelled.")
            existing.is_admin = True
            existing.is_active = True
            db.session.commit()
            print(f"{existing.name} is now an admin.")
            return

        name = input("Full name: ").strip() or "DermPaw Admin"
        password = getpass.getpass("Password: ")
        if getpass.getpass("Confirm password: ") != password:
            sys.exit("Passwords do not match.")
        if not is_password_strong(password):
            sys.exit("Password must be 8+ characters with upper, lower, number and special character.")

        admin = User(
            name=name,
            email=email,
            password_hash=bcrypt.generate_password_hash(password).decode("utf-8"),
            consent_status=True,
            is_vet=False,
            is_verified=True,
            is_admin=True,
            is_active=True,
        )
        db.session.add(admin)
        db.session.commit()
        print(f"Admin account created for {email} (user_id {admin.user_id}).")


if __name__ == "__main__":
    main()
