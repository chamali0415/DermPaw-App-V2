# DermPaw

A mobile application for image-based classification of canine skin diseases, developed as a final-year project at Rajarata University of Sri Lanka.

## Overview

DermPaw helps dog owners get a preliminary assessment of common canine skin conditions by uploading a photo, which is classified using an on-device/server-side machine learning model. Cases can be flagged for review by a licensed veterinarian, who can view the image, confirm or correct the AI's diagnosis, and leave treatment notes.

## Classification targets

- Fungal (Dandruff)
- Healthy
- Hypersensitivity Allergy (Tick dermatitis)
- Mange
- Ringworm

## Tech stack

- **Frontend:** Flutter (Android/Windows)
- **Backend:** Flask (Python), REST API
- **Database:** MySQL
- **ML model:** TensorFlow Lite, MobileNetV3-Small (transfer learning)

## Key features

- Image-based skin condition classification with confidence scoring
- Veterinarian review workflow (approve or override AI diagnosis, treatment notes)
- Vet registration with manual admin verification (B.V.Sc. registration number)
- Owner feedback per diagnosis
- App-wide rating and review system
- Diagnosis history with vet review visibility

## Team — Fusion Five

Supervised by Ms. W. B. P. N. Herath, Department of Computer Sciences, Rajarata University of Sri Lanka.

| Member | Branch | Responsibilities |
|---|---|---|
| W. M. C. T. Weerasinghe (Chamali) | `Chamali` | Backend architecture, ML pipeline, FR7–FR10, FR21–FR22 |
| M. K. G. B. M. Maneth (Manuri) | `Manuri` | FR1–FR6 |
| M. H. Ishini | `Ishini` | FR11–FR13, FR17, FR23–FR24 |
| D. M. U. Weerasekara (Dinithi) | `Dinithi` | FR14–FR16, FR18–FR19, FR29 |
| T. H. D. V. Panchali (Bisura) | `Bisura` | FR20, FR25–FR28, FR30 |

## Project structure
DermPaw-App-V2/
├── canine_skin_app/ # Flutter mobile application
├── model/ # Trained TFLite model + labels
├── app.py # Flask application entry point
├── auth.py # Authentication (register/login)
├── admin.py # Admin vet-verification endpoints
├── app_review.py # App rating/review endpoints
├── classify.py # ML inference endpoint
├── dogs.py # Dog & image upload endpoints
├── feedback.py # Per-diagnosis owner feedback
├── history.py # Diagnosis history endpoint
├── models.py # SQLAlchemy database models
├── password_reset.py # Password reset flow
├── profile.py # User profile endpoints
├── vet_review.py # Vet review workflow
└── requirements.txt


## Setup notes

- Requires a `.env` file (not committed) with `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_NAME`, `JWT_SECRET_KEY`, `MAIL_USERNAME`, `MAIL_PASSWORD`
- Backend: `pip install -r requirements.txt`, then `python app.py`
- Flutter app: update `baseUrl` in `lib/core/services/api_service.dart` to match your backend's address

