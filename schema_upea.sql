-- =====================================================================
-- SISTEMA UNIVERSITARIO DE ADMISIÓN Y PREUNIVERSITARIO UPEA
-- BASE DE DATOS NORMALIZADA EN 1FN, 2FN Y 3FN (TERCERA FORMA NORMAL)
-- Motor: PostgreSQL 17 / Compatible con pgAdmin 4
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================================
-- 1. CATÁLOGOS BASE (ATOMICIDAD Y DOMINIOS 1FN / 3FN)
-- =====================================================================

-- Roles del sistema (Estudiante, Docente, Encargado)
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(255)
);

-- Tipos de Documento de Identidad (CI, Pasaporte, etc.)
CREATE TABLE tipos_documento (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE NOT NULL,
    nombre VARCHAR(50) NOT NULL
);

-- Departamentos / Sedes (Evita redundancia transitiva en ubicaciones)
CREATE TABLE departamentos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(10) UNIQUE NOT NULL,
    nombre VARCHAR(60) NOT NULL
);

-- Días de la semana para horarios atómicos (1FN: sin grupos multivaluados)
CREATE TABLE dias_semana (
    id SERIAL PRIMARY KEY,
    numero_dia SMALLINT UNIQUE NOT NULL CHECK (numero_dia BETWEEN 1 AND 7),
    abreviatura VARCHAR(10) UNIQUE NOT NULL,
    nombre VARCHAR(20) NOT NULL
);

-- Estados de la Inscripción (Borrador, En revisión, Aprobado, Observado, Finalizado)
CREATE TABLE estados_inscripcion (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(200)
);

-- Estados del Documento (Pendiente, En revisión, Validado, Observado)
CREATE TABLE estados_documento (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    descripcion VARCHAR(200)
);

-- Estados del Pago (Pendiente, Pagado, Anulado)
CREATE TABLE estados_pago (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    nombre VARCHAR(50) NOT NULL
);

-- =====================================================================
-- 2. OFERTA ACADÉMICA Y CONVOCATORIAS (2FN Y 3FN)
-- =====================================================================

CREATE TABLE convocatorias (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    gestion INT NOT NULL DEFAULT 2027,
    periodo VARCHAR(50) NOT NULL DEFAULT 'Primera convocatoria',
    fecha_inicio DATE NOT NULL,
    fecha_limite DATE NOT NULL,
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE areas_academicas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    icono VARCHAR(10) DEFAULT '✦'
);

CREATE TABLE carreras (
    id SERIAL PRIMARY KEY,
    area_id INT NOT NULL REFERENCES areas_academicas(id) ON DELETE RESTRICT,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    duracion_anios INT DEFAULT 5,
    modalidad VARCHAR(50) DEFAULT 'Semestral',
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE materias (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    creditos INT DEFAULT 4,
    nivel VARCHAR(50) DEFAULT 'Preuniversitario',
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE carrera_materias (
    id SERIAL PRIMARY KEY,
    carrera_id INT NOT NULL REFERENCES carreras(id) ON DELETE CASCADE,
    materia_id INT NOT NULL REFERENCES materias(id) ON DELETE CASCADE,
    es_obligatoria BOOLEAN DEFAULT TRUE,
    UNIQUE(carrera_id, materia_id)
);

CREATE TABLE aulas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    edificio VARCHAR(100) DEFAULT 'Edificio Central UPEA',
    capacidad INT DEFAULT 40
);

-- Horarios Atómicos (1FN/3FN: día atómico + aula atómica + intervalo de horas)
CREATE TABLE horarios (
    id SERIAL PRIMARY KEY,
    materia_id INT NOT NULL REFERENCES materias(id) ON DELETE CASCADE,
    aula_id INT NOT NULL REFERENCES aulas(id) ON DELETE RESTRICT,
    dia_id INT NOT NULL REFERENCES dias_semana(id) ON DELETE RESTRICT,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    cupos_disponibles INT DEFAULT 40,
    CONSTRAINT chk_horas CHECK (hora_inicio < hora_fin)
);

-- =====================================================================
-- 3. USUARIOS Y PERFILES (ESTRUCTURA RELACIONAL 3FN)
-- =====================================================================

CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    rol_id INT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    tipo_documento_id INT NOT NULL REFERENCES tipos_documento(id) ON DELETE RESTRICT,
    numero_documento VARCHAR(30) NOT NULL,
    expedicion_id INT REFERENCES departamentos(id) ON DELETE RESTRICT,
    email VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(30),
    avatar_iniciales VARCHAR(5),
    activo BOOLEAN DEFAULT TRUE,
    ultimo_acceso TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_usuario_documento UNIQUE (tipo_documento_id, numero_documento, expedicion_id)
);

CREATE TABLE estudiantes_perfil (
    id SERIAL PRIMARY KEY,
    usuario_id INT UNIQUE NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    codigo_estudiante VARCHAR(30) UNIQUE NOT NULL,
    colegio_egreso VARCHAR(150),
    anio_bachiller INT,
    direccion TEXT,
    departamento_residencia_id INT REFERENCES departamentos(id),
    ciudad VARCHAR(100) DEFAULT 'El Alto',
    habilitado_primer_semestre BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE docentes_perfil (
    id SERIAL PRIMARY KEY,
    usuario_id INT UNIQUE NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    codigo_docente VARCHAR(30) UNIQUE NOT NULL,
    especialidad VARCHAR(150),
    grado_academico VARCHAR(50) DEFAULT 'Licenciatura',
    habilitado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE docente_materias (
    id SERIAL PRIMARY KEY,
    docente_id INT NOT NULL REFERENCES docentes_perfil(id) ON DELETE CASCADE,
    materia_id INT NOT NULL REFERENCES materias(id) ON DELETE CASCADE,
    gestion INT DEFAULT 2027,
    periodo VARCHAR(50) DEFAULT '1er Semestre',
    UNIQUE(docente_id, materia_id, gestion, periodo)
);

-- =====================================================================
-- 4. TRÁMITE DE INSCRIPCIÓN Y REQUISITOS (NORMALIZACIÓN 3FN)
-- =====================================================================

CREATE TABLE requisitos_catalogo (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    obligatorio BOOLEAN DEFAULT TRUE,
    formato_permitido VARCHAR(50) DEFAULT 'PDF, JPG, PNG',
    tamano_maximo_mb NUMERIC(4, 1) DEFAULT 5.0
);

CREATE TABLE inscripciones (
    id SERIAL PRIMARY KEY,
    numero_tramite VARCHAR(50) UNIQUE NOT NULL,
    estudiante_id INT NOT NULL REFERENCES estudiantes_perfil(id) ON DELETE CASCADE,
    convocatoria_id INT NOT NULL REFERENCES convocatorias(id) ON DELETE RESTRICT,
    carrera_id INT NOT NULL REFERENCES carreras(id) ON DELETE RESTRICT,
    estado_id INT NOT NULL REFERENCES estados_inscripcion(id) ON DELETE RESTRICT,
    paso_actual SMALLINT DEFAULT 3 CHECK (paso_actual BETWEEN 1 AND 4),
    porcentaje_progreso SMALLINT DEFAULT 75 CHECK (porcentaje_progreso BETWEEN 0 AND 100),
    observaciones_generales TEXT,
    fecha_inscripcion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inscripcion_horarios (
    id SERIAL PRIMARY KEY,
    inscripcion_id INT NOT NULL REFERENCES inscripciones(id) ON DELETE CASCADE,
    horario_id INT NOT NULL REFERENCES horarios(id) ON DELETE RESTRICT,
    fecha_asignacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(inscripcion_id, horario_id)
);

CREATE TABLE documentos_estudiante (
    id SERIAL PRIMARY KEY,
    inscripcion_id INT NOT NULL REFERENCES inscripciones(id) ON DELETE CASCADE,
    requisito_id INT NOT NULL REFERENCES requisitos_catalogo(id) ON DELETE RESTRICT,
    estado_id INT NOT NULL REFERENCES estados_documento(id) ON DELETE RESTRICT,
    nombre_archivo VARCHAR(255) NOT NULL,
    ruta_archivo VARCHAR(500),
    tamano_archivo_mb NUMERIC(5, 2) DEFAULT 1.2,
    observacion_encargado TEXT,
    revisado_por INT REFERENCES usuarios(id) ON DELETE SET NULL,
    fecha_subida TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_revision TIMESTAMP WITH TIME ZONE
);

-- =====================================================================
-- 5. CALIFICACIONES (3FN: NOTA SOBRE 100 GENERADA, SIN REDUNDANCIA)
-- =====================================================================

CREATE TABLE calificaciones (
    id SERIAL PRIMARY KEY,
    estudiante_id INT NOT NULL REFERENCES estudiantes_perfil(id) ON DELETE CASCADE,
    materia_id INT NOT NULL REFERENCES materias(id) ON DELETE RESTRICT,
    docente_id INT REFERENCES docentes_perfil(id) ON DELETE SET NULL,
    periodo VARCHAR(50) DEFAULT '1er Semestre 2027',
    nota_final NUMERIC(3, 1) NOT NULL CHECK (nota_final >= 0.0 AND nota_final <= 5.0),
    -- Regla 3FN: La nota sobre 100 es calculada funcionalmente, nunca dependiente ni editable por separado
    nota_sobre_100 NUMERIC(5, 2) GENERATED ALWAYS AS (ROUND((nota_final * 20.0)::numeric, 2)) STORED,
    estado_academico VARCHAR(30) DEFAULT 'Habilitado',
    fecha_calificacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(estudiante_id, materia_id, periodo)
);

-- =====================================================================
-- 6. ARANCELES, PAGOS Y MATRÍCULAS (3FN)
-- =====================================================================

CREATE TABLE conceptos_arancel (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    descripcion VARCHAR(150) NOT NULL,
    monto NUMERIC(10, 2) NOT NULL CHECK (monto >= 0),
    moneda VARCHAR(10) DEFAULT 'BOB',
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE pagos (
    id SERIAL PRIMARY KEY,
    inscripcion_id INT NOT NULL REFERENCES inscripciones(id) ON DELETE CASCADE,
    arancel_id INT NOT NULL REFERENCES conceptos_arancel(id) ON DELETE RESTRICT,
    estado_id INT NOT NULL REFERENCES estados_pago(id) ON DELETE RESTRICT,
    metodo_pago VARCHAR(50),
    numero_comprobante VARCHAR(50) UNIQUE,
    fecha_pago TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE matriculas (
    id SERIAL PRIMARY KEY,
    inscripcion_id INT UNIQUE NOT NULL REFERENCES inscripciones(id) ON DELETE CASCADE,
    numero_matricula VARCHAR(50) UNIQUE NOT NULL,
    codigo_verificacion VARCHAR(50) UNIQUE NOT NULL,
    fecha_emision TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    constancia_url VARCHAR(500)
);

-- =====================================================================
-- 7. NOTIFICACIONES Y AUDITORÍA
-- =====================================================================

CREATE TABLE notificaciones (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    titulo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    tipo VARCHAR(30) DEFAULT 'info',
    leida BOOLEAN DEFAULT FALSE,
    fecha_envio TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE auditoria_revisiones (
    id SERIAL PRIMARY KEY,
    encargado_id INT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    documento_id INT REFERENCES documentos_estudiante(id) ON DELETE SET NULL,
    inscripcion_id INT REFERENCES inscripciones(id) ON DELETE CASCADE,
    accion VARCHAR(100) NOT NULL,
    observacion_registrada TEXT,
    estado_resultante_id INT NOT NULL REFERENCES estados_documento(id),
    fecha_accion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================================
-- 8. VISTAS ANALÍTICAS PARA PGADMIN 4
-- =====================================================================

CREATE OR REPLACE VIEW v_revisiones_encargado AS
SELECT 
    d.id AS documento_id,
    u.id AS usuario_id,
    CONCAT(u.nombres, ' ', u.apellidos) AS estudiante,
    u.email AS correo,
    rc.nombre AS documento,
    c.nombre AS programa,
    ed.nombre AS estado_documento,
    d.observacion_encargado AS observacion,
    d.fecha_subida,
    d.fecha_revision
FROM documentos_estudiante d
JOIN requisitos_catalogo rc ON d.requisito_id = rc.id
JOIN estados_documento ed ON d.estado_id = ed.id
JOIN inscripciones i ON d.inscripcion_id = i.id
JOIN estudiantes_perfil ep ON i.estudiante_id = ep.id
JOIN usuarios u ON ep.usuario_id = u.id
JOIN carreras c ON i.carrera_id = c.id;

CREATE OR REPLACE VIEW v_calificaciones_docentes AS
SELECT 
    cal.id AS calificacion_id,
    CONCAT(u.nombres, ' ', u.apellidos) AS estudiante,
    ep.codigo_estudiante,
    m.nombre AS materia,
    cal.nota_final,
    cal.nota_sobre_100,
    cal.estado_academico,
    CONCAT(ud.nombres, ' ', ud.apellidos) AS docente,
    cal.periodo
FROM calificaciones cal
JOIN estudiantes_perfil ep ON cal.estudiante_id = ep.id
JOIN usuarios u ON ep.usuario_id = u.id
JOIN materias m ON cal.materia_id = m.id
LEFT JOIN docentes_perfil dp ON cal.docente_id = dp.id
LEFT JOIN usuarios ud ON dp.usuario_id = ud.id;

CREATE OR REPLACE VIEW v_resumen_inscripciones AS
SELECT 
    i.id AS inscripcion_id,
    i.numero_tramite,
    ep.codigo_estudiante,
    CONCAT(u.nombres, ' ', u.apellidos) AS estudiante,
    u.email,
    CONCAT(u.numero_documento, ' ', COALESCE(dep.codigo, '')) AS ci_completo,
    c.nombre AS carrera_postulada,
    area.nombre AS area_academica,
    ei.nombre AS estado_inscripcion,
    i.porcentaje_progreso,
    i.paso_actual,
    COALESCE(epago.nombre, 'No iniciado') AS estado_pago,
    COALESCE(m.numero_matricula, 'Sin matricular') AS numero_matricula,
    ep.habilitado_primer_semestre,
    i.fecha_inscripcion
FROM inscripciones i
JOIN estudiantes_perfil ep ON i.estudiante_id = ep.id
JOIN usuarios u ON ep.usuario_id = u.id
LEFT JOIN departamentos dep ON u.expedicion_id = dep.id
JOIN carreras c ON i.carrera_id = c.id
JOIN areas_academicas area ON c.area_id = area.id
JOIN estados_inscripcion ei ON i.estado_id = ei.id
LEFT JOIN pagos p ON p.inscripcion_id = i.id
LEFT JOIN estados_pago epago ON p.estado_id = epago.id
LEFT JOIN matriculas m ON m.inscripcion_id = i.id;

CREATE OR REPLACE VIEW v_estadisticas_dashboard AS
SELECT 
    (SELECT COUNT(*) FROM inscripciones) AS total_inscripciones,
    (SELECT COUNT(*) FROM documentos_estudiante de JOIN estados_documento ed ON de.estado_id = ed.id WHERE ed.codigo = 'EN_REVISION') AS documentos_en_revision,
    (SELECT COUNT(*) FROM inscripciones i JOIN estados_inscripcion ei ON i.estado_id = ei.id WHERE ei.codigo IN ('APROBADO', 'FINALIZADO')) AS inscripciones_aprobadas,
    (SELECT COUNT(*) FROM inscripciones i JOIN estados_inscripcion ei ON i.estado_id = ei.id WHERE ei.codigo = 'BORRADOR') AS inscripciones_borrador,
    (SELECT COUNT(*) FROM carreras WHERE activo = TRUE) AS total_carreras,
    (SELECT COUNT(*) FROM areas_academicas) AS total_areas;

CREATE OR REPLACE VIEW v_horarios_completos AS
SELECT 
    h.id AS horario_id,
    m.nombre AS materia,
    ds.nombre AS dia,
    TO_CHAR(h.hora_inicio, 'HH24:MI') AS hora_inicio,
    TO_CHAR(h.hora_fin, 'HH24:MI') AS hora_fin,
    a.nombre AS aula,
    a.edificio,
    h.cupos_disponibles
FROM horarios h
JOIN materias m ON h.materia_id = m.id
JOIN dias_semana ds ON h.dia_id = ds.id
JOIN aulas a ON h.aula_id = a.id;

-- =====================================================================
-- 9. USUARIO ADMINISTRADOR PRINCIPAL
-- =====================================================================
INSERT INTO usuarios (
    rol_id, tipo_documento_id, numero_documento, expedicion_id, 
    email, password_hash, nombres, apellidos, telefono, avatar_iniciales, activo
) VALUES (
    (SELECT id FROM roles WHERE codigo = 'ADMIN'), 
    (SELECT id FROM tipos_documento WHERE codigo = 'CI'), 
    '10000001', 
    (SELECT id FROM departamentos WHERE codigo = 'LP'), 
    'wilson@hotmail.com', 
    '1234', 
    'Wilson', 
    'Administrador Principal', 
    '+591 70000000', 
    'WA', 
    TRUE
) ON CONFLICT (email) DO NOTHING;

