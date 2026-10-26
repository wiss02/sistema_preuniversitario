# Sistema Preuniversitario UPEA — fase funcional

Interfaz 3D ligera (HTML/CSS/JavaScript), servidor Flask y persistencia SQL.

## Funciones implementadas

- Registro real de estudiantes con contraseña protegida por hash.
- Inicio de sesión con roles determinados por el servidor, no por el usuario.
- Guardado y recuperación de carrera y materias para estudiantes.
- Panel de administrador con métricas y creación de usuarios por roles.
- Tokens CSRF, cookie de sesión HttpOnly/SameSite y comprobación de permisos.
- Portal docente, documentos, pagos y calificaciones identificados como
  **pendientes**; no hay operaciones simuladas de pago ni aprobación.
- Diseño 3D en CSS que respeta la opción de movimiento reducido.

## Ejecución local

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python server.py
```

Abre `http://127.0.0.1:5000`. Sin `DATABASE_URL`, se utiliza SQLite **solo para
pruebas locales**. Para PostgreSQL, configura `DATABASE_URL` de forma privada.

Para iniciar un administrador en una base de datos nueva, define una sola vez
`BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD` (mínimo 12 caracteres)
antes de arrancar el servidor. Se crea una cuenta con contraseña hasheada si
todavía no existe. Luego retira la contraseña de las variables de entorno.

## Render: nuevo servicio dinámico

El archivo `render.yaml` prepara un **Web Service Python** y una instancia
**PostgreSQL Free**, separados del Static Site ya publicado. En Render:

1. Selecciona **New → Blueprint** y el repositorio de GitHub.
2. Revisa los recursos antes de aprobarlos y confirma el plan gratuito.
3. Cuando el despliegue termine, abre `/api/health` en la nueva URL. Debe
   mostrar `{"status":"ok","database":"connected"}`.
4. Configura el administrador inicial de forma privada. No pegues contraseñas
   ni URLs de base de datos en GitHub ni en mensajes.

**Atención:** PostgreSQL Free de Render vence a los 30 días, tiene un período
de gracia de 14 días y puede eliminar los datos si no se actualiza el plan.
No es apropiado para producción con inscripciones reales. El Web Service Free
también puede suspenderse por inactividad.

## Pruebas

```bash
python -m unittest discover -s tests -v
node --check app.js
```

Las pruebas utilizan una base temporal SQLite y no modifican los datos de Render.

## Seguridad y alcance

No se almacenan contraseñas en texto plano y no existe un administrador con
clave predeterminada. Los archivos SQL y Markdown no se sirven por HTTP.
Esta fase todavía requiere copias de seguridad, límites de intentos de inicio
de sesión, recuperación de contraseña y pruebas de seguridad antes de un uso
institucional con datos personales.

El diseño del prototipo no implica afiliación oficial con la UPEA.
