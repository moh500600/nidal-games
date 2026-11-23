# Nidal Games

Game library: Django REST backend (PostgreSQL), React web (AR/EN, RTL), Flutter Android client. Cyber Azure design.

## Run backend
    cd backend && python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
    python manage.py migrate && python manage.py seed_catalog
    python manage.py sync_steam 1091500 570 730 230410 1145360 1245620 1086940 292030   # official Steam records
    python manage.py createsuperuser
    python manage.py runserver        # admin at /admin/, API at /api/
Set POSTGRES_* (see .env.example) to use PostgreSQL; otherwise SQLite is used for development.
Tests: `python manage.py test` (24 tests, also run against PostgreSQL 16).

## Web
    cd web && npm install && npm run dev   (build: npm run build)

## Android
    cd mobile && flutter pub get && flutter analyze && flutter test && flutter build apk --release
Open Settings in the app and enter your HTTPS backend URL for accounts/sync. Without it the app browses a saved Steam catalog only.
Gradle on small machines: android/gradle.properties caps heap at 768 MB, 1 worker.

## Architecture notes
- Auth: Django session + CSRF (not JWT). Web uses cookies; the Flutter client stores the session/CSRF cookies itself. Use HTTPS in production. Passwords hashed by Django (PBKDF2); login throttled.
- API keys stay server-side. RAWG free tier is non-commercial only; IGDB requires Twitch credentials; both disabled until keys are supplied.
- Games link to official stores only; no download files are hosted. Downloads are "opened official page"/"marked downloaded".
- Collections return full nested `games_detail` so filtering/pagination never truncates them.
- Not done: iOS build (needs macOS/Xcode), production hosting, cloud image storage (local media dir used).
