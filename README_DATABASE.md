# Base de datos del preuniversitario

## Estado actual

El antiguo `schema_upea.sql` describe 19 tablas, relaciones y vistas para una
versión más extensa del sistema. **No se ejecuta automáticamente** y no debe
confundirse con las tablas activas del backend.

La primera fase funcional usa PostgreSQL con SQLAlchemy y las tablas:

- `portal_users`: cuentas de estudiante, docente y administrador, con hashes
  seguros de contraseñas.
- `portal_enrollments`: carrera y materias elegidas por cada estudiante.

Estas tablas se crean automáticamente al iniciar `server.py` con `DATABASE_URL`
configurada. El inicio de sesión y las operaciones administrativas se validan
en el servidor; el navegador nunca recibe credenciales de PostgreSQL.

## Conexión local

Si usas PostgreSQL en tu computadora, configura la variable `DATABASE_URL`,
por ejemplo usando un usuario de base de datos dedicado. No subas la URL real,
contraseñas, archivos `.env` ni copias de datos personales a GitHub.

Sin `DATABASE_URL`, el servidor usa SQLite únicamente para desarrollo local.
En Render, `DATABASE_URL` y `SECRET_KEY` son obligatorias.

## Siguiente fase

Los módulos de documentos, pagos, matrícula, calificaciones y notificaciones
siguen pendientes. No simulan guardados ni pagos en la versión funcional.
Antes de operar con datos reales se deberán agregar migraciones, respaldos,
política de privacidad y pruebas de seguridad adicionales.
