"""Backend de la primera fase funcional del portal preuniversitario.

La base de datos se configura mediante DATABASE_URL. El archivo
schema_upea.sql del prototipo anterior es una referencia para futuras
migraciones; este backend crea únicamente las tablas que realmente usa.
"""

import os
import re
import secrets
from datetime import datetime, timezone
from functools import wraps
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory, session
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from werkzeug.security import check_password_hash, generate_password_hash


db = SQLAlchemy()
BASE_DIR = Path(__file__).resolve().parent
ROLES = {"student", "teacher", "admin"}
CAREERS = {
    "Medicina", "Enfermería", "Ingeniería de Sistemas", "Ingeniería Civil",
    "Ingeniería Ambiental", "Administración de Empresas", "Contaduría Pública",
    "Psicología", "Comunicación Social", "Arquitectura", "Ingeniería Agronómica",
    "Medicina Veterinaria y Zootecnia", "Odontología",
}
SUBJECTS = {"Matemática", "Lenguaje", "Ciencias naturales", "Introducción profesional"}
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def utc_now():
    return datetime.now(timezone.utc)


class User(db.Model):
    __tablename__ = "portal_users"

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(180), nullable=False, unique=True, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(100), nullable=False)
    last_name = db.Column(db.String(100), nullable=False)
    document_type = db.Column(db.String(40), nullable=False, default="CI")
    document_number = db.Column(db.String(40), nullable=False)
    detail = db.Column(db.String(180), nullable=False, default="")
    role = db.Column(db.String(12), nullable=False, default="student")
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=utc_now)
    enrollment = db.relationship("Enrollment", back_populates="user", uselist=False, cascade="all, delete-orphan")

    def public(self):
        return {
            "id": self.id,
            "email": self.email,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "role": self.role,
        }

    def admin_public(self):
        return {**self.public(), "document_number": self.document_number,
                "document_type": self.document_type, "detail": self.detail}


class Enrollment(db.Model):
    __tablename__ = "portal_enrollments"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("portal_users.id"), nullable=False, unique=True)
    career = db.Column(db.String(120), nullable=False)
    subjects = db.Column(db.JSON, nullable=False, default=list)
    status = db.Column(db.String(24), nullable=False, default="borrador")
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = db.Column(db.DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
    user = db.relationship("User", back_populates="enrollment")

    def public(self):
        return {"id": self.id, "career": self.career, "subjects": self.subjects, "status": self.status}


def fail(message, status=400):
    return jsonify({"error": message}), status


def json_data():
    return request.get_json(silent=True) if request.is_json else None


def clean(value, max_length):
    return str(value or "").strip()[:max_length + 1]


def validate_user(data, *, require_document=True):
    first_name = clean(data.get("first_name"), 100)
    last_name = clean(data.get("last_name"), 100)
    email = clean(data.get("email"), 180).lower()
    password = data.get("password", "")
    document_number = clean(data.get("document_number"), 40)
    document_type = clean(data.get("document_type", "CI"), 40)
    detail = clean(data.get("detail"), 180)
    if not first_name or not last_name or len(first_name) > 100 or len(last_name) > 100:
        return None, "Introduce nombres y apellidos válidos."
    if len(email) > 180 or not EMAIL_RE.fullmatch(email):
        return None, "El correo electrónico no es válido."
    if not isinstance(password, str) or len(password) < 10 or len(password) > 128:
        return None, "La contraseña debe tener entre 10 y 128 caracteres."
    if require_document and (not document_number or len(document_number) > 40):
        return None, "Introduce el número de documento."
    if len(document_type) > 40:
        return None, "El tipo de documento no es válido."
    if len(detail) > 180:
        return None, "El detalle del usuario es demasiado largo."
    return {
        "first_name": first_name,
        "last_name": last_name,
        "email": email,
        "password_hash": generate_password_hash(password),
        "document_type": document_type or "CI",
        "document_number": document_number or "pendiente",
        "detail": detail,
    }, None


def require_role(role=None):
    def decorator(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            user_id = session.get("user_id")
            user = db.session.get(User, user_id) if isinstance(user_id, int) else None
            if user is None:
                return fail("Inicia sesión para continuar.", 401)
            if role and user.role != role:
                return fail("No tienes permiso para esta acción.", 403)
            return view(user, *args, **kwargs)
        return wrapped
    return decorator


def create_app(test_config=None):
    app = Flask(__name__, static_folder=None)
    database_url = os.environ.get("DATABASE_URL", "")
    if database_url.startswith("postgres://"):
        database_url = "postgresql://" + database_url[len("postgres://"):]
    if database_url.startswith("postgresql://"):
        database_url = "postgresql+psycopg://" + database_url[len("postgresql://"):]

    if os.environ.get("RENDER") and (not database_url or not os.environ.get("SECRET_KEY")):
        raise RuntimeError("En Render se requieren DATABASE_URL y SECRET_KEY.")

    app.config.update(
        SECRET_KEY=os.environ.get("SECRET_KEY") or secrets.token_hex(32),
        SQLALCHEMY_DATABASE_URI=database_url or "sqlite:///preuniversitario_local.db",
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=bool(os.environ.get("RENDER")),
        MAX_CONTENT_LENGTH=1024 * 1024,
    )
    if test_config:
        app.config.update(test_config)
    db.init_app(app)

    with app.app_context():
        db.create_all()
        # Nunca crear un administrador con contraseñas de ejemplo.
        admin_email = os.environ.get("BOOTSTRAP_ADMIN_EMAIL", "").strip().lower()
        admin_password = os.environ.get("BOOTSTRAP_ADMIN_PASSWORD", "")
        if admin_email and len(admin_password) >= 12 and EMAIL_RE.fullmatch(admin_email):
            if db.session.scalar(db.select(User).filter_by(email=admin_email)) is None:
                db.session.add(User(email=admin_email, password_hash=generate_password_hash(admin_password),
                                    first_name="Administración", last_name="Preuniversitario",
                                    document_type="CI", document_number="administracion", role="admin"))
                db.session.commit()

    @app.after_request
    def headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["X-Frame-Options"] = "DENY"
        return response

    @app.before_request
    def csrf_protection():
        if request.path.startswith("/api/") and request.method in {"POST", "PUT", "PATCH", "DELETE"}:
            sent = request.headers.get("X-CSRF-Token", "")
            expected = session.get("csrf")
            if not expected or not secrets.compare_digest(sent, expected):
                return fail("Sesión de seguridad caducada. Recarga la página.", 403)

    @app.get("/")
    def home():
        return send_from_directory(BASE_DIR, "index.html")

    @app.get("/<path:filename>")
    def assets(filename):
        if filename not in {"styles.css", "design3d.css", "app.js", "upea-logo.jfif"}:
            return fail("Archivo no encontrado.", 404)
        return send_from_directory(BASE_DIR, filename)

    @app.get("/api/csrf")
    def csrf():
        session.setdefault("csrf", secrets.token_urlsafe(32))
        return jsonify({"csrf": session["csrf"]})

    @app.get("/api/health")
    def health():
        try:
            db.session.execute(text("SELECT 1"))
            return jsonify({"status": "ok", "database": "connected"})
        except SQLAlchemyError:
            return fail("La base de datos no está disponible.", 503)

    @app.post("/api/auth/register")
    def register():
        data = json_data()
        if not isinstance(data, dict):
            return fail("Envía un formulario válido.")
        fields, error = validate_user(data)
        if error:
            return fail(error)
        user = User(**fields, role="student")
        db.session.add(user)
        try:
            db.session.commit()
        except IntegrityError:
            db.session.rollback()
            return fail("Ya existe una cuenta con ese correo.", 409)
        session.clear()
        session["user_id"] = user.id
        session["csrf"] = secrets.token_urlsafe(32)
        return jsonify({"user": user.public(), "csrf": session["csrf"]}), 201

    @app.post("/api/auth/login")
    def login():
        data = json_data()
        if not isinstance(data, dict):
            return fail("Envía un formulario válido.")
        email = clean(data.get("email"), 180).lower()
        password = data.get("password", "")
        user = db.session.scalar(db.select(User).filter_by(email=email)) if EMAIL_RE.fullmatch(email) else None
        if user is None or not isinstance(password, str) or not check_password_hash(user.password_hash, password):
            return fail("Correo o contraseña incorrectos.", 401)
        session.clear()
        session["user_id"] = user.id
        session["csrf"] = secrets.token_urlsafe(32)
        return jsonify({"user": user.public(), "csrf": session["csrf"]})

    @app.post("/api/auth/logout")
    def logout():
        session.clear()
        return jsonify({"ok": True})

    @app.get("/api/auth/me")
    @require_role()
    def me(user):
        return jsonify({"user": user.public()})

    @app.route("/api/enrollment", methods=["GET", "PUT"])
    @require_role("student")
    def enrollment(user):
        if request.method == "GET":
            return jsonify({"enrollment": user.enrollment.public() if user.enrollment else None})
        data = json_data()
        if not isinstance(data, dict):
            return fail("Envía un formulario válido.")
        career = clean(data.get("career"), 120)
        subjects = data.get("subjects", [])
        if career not in CAREERS:
            return fail("Selecciona una carrera válida.")
        if not isinstance(subjects, list) or len(subjects) > 4 or any(item not in SUBJECTS for item in subjects):
            return fail("Selecciona materias válidas.")
        if user.enrollment is None:
            user.enrollment = Enrollment(career=career, subjects=list(dict.fromkeys(subjects)))
        else:
            user.enrollment.career = career
            user.enrollment.subjects = list(dict.fromkeys(subjects))
        db.session.commit()
        return jsonify({"enrollment": user.enrollment.public()})

    @app.get("/api/admin/stats")
    @require_role("admin")
    def stats(_user):
        return jsonify({
            "users": db.session.scalar(db.select(func.count(User.id))),
            "enrollments": db.session.scalar(db.select(func.count(Enrollment.id))),
            "pending": db.session.scalar(db.select(func.count(Enrollment.id)).filter_by(status="borrador")),
            "approved": db.session.scalar(db.select(func.count(Enrollment.id)).filter_by(status="aprobado")),
        })

    @app.route("/api/admin/users", methods=["GET", "POST"])
    @require_role("admin")
    def admin_users(_user):
        if request.method == "GET":
            users = db.session.scalars(db.select(User).order_by(User.created_at.desc()).limit(100)).all()
            return jsonify({"users": [user.admin_public() for user in users]})
        data = json_data()
        if not isinstance(data, dict):
            return fail("Envía un formulario válido.")
        fields, error = validate_user(data)
        if error:
            return fail(error)
        role = data.get("role", "student")
        if role not in ROLES:
            return fail("Rol no válido.")
        new_user = User(**fields, role=role)
        db.session.add(new_user)
        try:
            db.session.commit()
        except IntegrityError:
            db.session.rollback()
            return fail("El correo ya está registrado.", 409)
        return jsonify({"user": new_user.admin_public()}), 201

    return app


app = create_app()


if __name__ == "__main__":
    app.run(debug=False)
