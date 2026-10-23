# Conexión a la Base de Datos en pgAdmin 4

## 📌 Datos de Conexión Exitosa
- **Host / Servidor**: `127.0.0.1` (o `localhost`)
- **Puerto**: `5432`
- **Base de Datos Creada**: `upea_inscripciones` (Arquitectura 1FN, 2FN y 3FN)
- **Usuario de Mantenimiento**: `postgres`
- **Codificación**: `UTF-8`

### 🔑 Credenciales Administrador Principal (Super Admin)
- **Correo**: `wilson@hotmail.com`
- **Contraseña**: `1234`
- **Rol**: `ADMIN` (Encargado / Administrador Principal)
- **Permisos**: Registro y gestión de usuarios para los 3 roles (Estudiantes, Docentes y Encargados).


---

## 🗺️ Cómo ver la Base de Datos en pgAdmin 4

1. Abre **pgAdmin 4**.
2. En el panel izquierdo de navegación (**Servers**):
   - Expande tu servidor (por ejemplo: `PostgreSQL 17`).
   - Expande **Databases**.
   - Haz clic derecho sobre **Databases** y selecciona **Refresh...** si no aparece inmediatamente.
   - Verás la base de datos **`upea_inscripciones`** (la base de datos previa `proyecto` fue eliminada como solicitaste).
3. Dentro de **`upea_inscripciones`**:
   - Expande **Schemas** -> **public**.
   - Expande **Tables (19)**: Encontrarás todas las tablas relacionales.
   - Expande **Views (4)**: Encontrarás las vistas listas para consultas directas.

---

## 👁️ Correspondencia entre la Interfaz Web y pgAdmin 4

| Elemento Visual en la Web | Tabla / Vista en pgAdmin 4 | Datos Visibles |
| :--- | :--- | :--- |
| **Inicio / Oferta Académica** | `areas_academicas` y `carreras` | 9 áreas académicas y las carreras (Medicina, Sistemas, etc.). |
| **Login y Roles** | `roles` y `usuarios` | Roles: estudiante, docente, admin. Credenciales y perfiles. |
| **Panel Estudiante (Juan David)** | `estudiantes_perfil`, `inscripciones` | Código `1002456`, progreso `75%`, paso `3`, carrera `Medicina`. |
| **Materias y Horarios** | `materias`, `horarios`, `inscripcion_materias` | Matemática (Lun/Mié 08:00), Lenguaje (Mar/Jue 10:00). |
| **Documentos y Observaciones** | `documentos_estudiante` | `cedula_juan.pdf` (Validado), `cert_hab.pdf` (Observado). |
| **Pagos y Arancel** | `pagos` | Arancel $ 150.000 / 150.00 BOB, comprobantes y estado. |
| **Portal Docente (María González)** | `v_calificaciones_docentes` / `calificaciones` | Juan David (Nota 4.5, Habilitado), Laura Gómez (Nota 3.8). |
| **Panel Encargado (Andrea Méndez)** | `v_revisiones_encargado` | Tabla de estudiantes con documentos en revisión y observaciones. |
| **Estadísticas del Dashboard** | `v_estadisticas_dashboard` | Totales: 248 inscripciones, 42 en revisión, 154 aprobadas. |

---

## 📝 Script SQL de Respaldo
El archivo completo de creación de tablas, relaciones y vistas se encuentra guardado en:
`schema_upea.sql`
