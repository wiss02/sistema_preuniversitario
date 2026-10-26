"""Pruebas de registro, autenticación, permisos y persistencia."""

import os
import tempfile
import unittest
from pathlib import Path

from server import create_app, db


class PortalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        db_path = Path(self.temp.name) / "portal-test.db"
        self.app = create_app({
            "TESTING": True,
            "SECRET_KEY": "solo-para-pruebas",
            "SQLALCHEMY_DATABASE_URI": f"sqlite:///{db_path}",
            "SESSION_COOKIE_SECURE": False,
        })
        self.client = self.app.test_client()
        self.csrf = self.client.get("/api/csrf").json["csrf"]

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.engine.dispose()
        self.temp.cleanup()

    def write(self, path, data, method="POST", csrf=None):
        return self.client.open(path, method=method, json=data,
                                headers={"X-CSRF-Token": csrf if csrf is not None else self.csrf})

    def register(self):
        result = self.write("/api/auth/register", {
            "first_name": "Ana", "last_name": "Quispe", "email": "ana@example.com",
            "document_type": "CI", "document_number": "1234567",
            "password": "UnPasswordLargo123!", "role": "admin"
        })
        self.assertEqual(result.status_code, 201)
        self.assertEqual(result.json["user"]["role"], "student")
        self.csrf = result.json["csrf"]
        return result

    def test_registration_login_and_enrollment_are_persistent(self):
        self.register()
        saved = self.write("/api/enrollment", {
            "career": "Ingeniería de Sistemas", "subjects": ["Matemática", "Lenguaje"]
        }, method="PUT")
        self.assertEqual(saved.status_code, 200)
        self.assertEqual(saved.json["enrollment"]["status"], "borrador")
        self.assertEqual(self.client.get("/api/enrollment").json["enrollment"]["career"], "Ingeniería de Sistemas")
        self.assertEqual(self.write("/api/auth/logout", {}).status_code, 200)
        self.csrf = self.client.get("/api/csrf").json["csrf"]
        self.assertEqual(self.client.get("/api/enrollment").status_code, 401)
        self.assertEqual(self.write("/api/auth/login", {"email": "ana@example.com", "password": "mala"}).status_code, 401)
        result = self.write("/api/auth/login", {"email": "ana@example.com", "password": "UnPasswordLargo123!"})
        self.assertEqual(result.status_code, 200)
        self.csrf = result.json["csrf"]
        self.assertEqual(self.client.get("/api/enrollment").json["enrollment"]["subjects"], ["Matemática", "Lenguaje"])
        self.assertEqual(self.client.get("/api/admin/users").status_code, 403)

    def test_security_and_validation(self):
        no_csrf = self.client.post("/api/auth/register", json={"email": "a@b.com"})
        self.assertEqual(no_csrf.status_code, 403)
        self.register()
        self.assertEqual(self.write("/api/enrollment", {"career": "Carrera inventada", "subjects": []}, method="PUT").status_code, 400)
        self.assertEqual(self.write("/api/enrollment", {"career": "Medicina", "subjects": ["Materia falsa"]}, method="PUT").status_code, 400)
        self.assertEqual(self.client.get("/README_DATABASE.md").status_code, 404)
        self.assertEqual(self.client.get("/schema_upea.sql").status_code, 404)
        for path in ["/", "/design3d.css"]:
            response = self.client.get(path)
            self.assertEqual(response.status_code, 200)
            response.close()
        self.assertEqual(self.client.get("/api/health").json["database"], "connected")

    def test_only_admin_can_create_user(self):
        previous_email = os.environ.get("BOOTSTRAP_ADMIN_EMAIL")
        previous_password = os.environ.get("BOOTSTRAP_ADMIN_PASSWORD")
        try:
            os.environ["BOOTSTRAP_ADMIN_EMAIL"] = "admin@example.com"
            os.environ["BOOTSTRAP_ADMIN_PASSWORD"] = "SuperSeguraClave123!"
            admin_db = Path(self.temp.name) / "admin-test.db"
            admin_app = create_app({
                "TESTING": True, "SECRET_KEY": "admin-pruebas",
                "SQLALCHEMY_DATABASE_URI": f"sqlite:///{admin_db}", "SESSION_COOKIE_SECURE": False,
            })
            admin_client = admin_app.test_client()
            token = admin_client.get("/api/csrf").json["csrf"]
            login = admin_client.post("/api/auth/login", json={"email": "admin@example.com", "password": "SuperSeguraClave123!"}, headers={"X-CSRF-Token": token})
            self.assertEqual(login.status_code, 200)
            token = login.json["csrf"]
            new_user = admin_client.post("/api/admin/users", json={
                "first_name": "Mario", "last_name": "Choque", "email": "mario@example.com",
                "password": "DocenteMuySeguro123", "document_number": "741852",
                "role": "teacher", "detail": "Matemática"
            }, headers={"X-CSRF-Token": token})
            self.assertEqual(new_user.status_code, 201)
            self.assertEqual(new_user.json["user"]["role"], "teacher")
            self.assertEqual(admin_client.get("/api/admin/stats").json["users"], 2)
            with admin_app.app_context():
                db.session.remove()
                db.engine.dispose()
        finally:
            if previous_email is None: os.environ.pop("BOOTSTRAP_ADMIN_EMAIL", None)
            else: os.environ["BOOTSTRAP_ADMIN_EMAIL"] = previous_email
            if previous_password is None: os.environ.pop("BOOTSTRAP_ADMIN_PASSWORD", None)
            else: os.environ["BOOTSTRAP_ADMIN_PASSWORD"] = previous_password


if __name__ == "__main__":
    unittest.main()
