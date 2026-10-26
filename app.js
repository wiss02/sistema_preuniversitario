/* Interfaz del portal conectada al backend Flask/PostgreSQL. */
const views = ['home', 'login', 'register', 'student', 'teacher', 'admin'];
const toast = document.getElementById('toast');
const roleViews = { student: 'student', teacher: 'teacher', admin: 'admin' };
let currentUser = null;
let csrfToken = '';

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  window.setTimeout(() => toast.classList.remove('show'), 4500);
}

function showView(name) {
  if (!views.includes(name)) name = 'home';
  if (['student', 'teacher', 'admin'].includes(name) && (!currentUser || roleViews[currentUser.role] !== name)) {
    name = 'login';
  }
  views.forEach(view => document.getElementById(`${view}-view`)?.classList.toggle('hidden', view !== name));
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    credentials: 'same-origin',
    ...options,
    headers: {
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...(options.method && options.method !== 'GET' ? { 'X-CSRF-Token': csrfToken } : {}),
      ...(options.headers || {})
    }
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `No se pudo completar la operación (${response.status}).`);
  return data;
}

function value(id) { return document.getElementById(id)?.value.trim() || ''; }
function initials(user) { return `${user.first_name[0] || ''}${user.last_name[0] || ''}`.toUpperCase(); }

function setBusy(form, busy) {
  const button = form.querySelector('button[type="submit"]');
  if (button) button.disabled = busy;
  form.setAttribute('aria-busy', String(busy));
}

async function enterPortal(user) {
  currentUser = user;
  showView(roleViews[user.role]);
  if (user.role === 'student') await populateStudent(user);
  if (user.role === 'admin') await populateAdmin(user);
  if (user.role === 'teacher') populateTeacher(user);
}

document.addEventListener('click', async (event) => {
  const logout = event.target.closest('.logout');
  if (logout) {
    event.preventDefault();
    try { await api('/api/auth/logout', { method: 'POST' }); } catch (_) { /* limpiar vista igualmente */ }
    currentUser = null;
    csrfToken = (await api('/api/csrf')).csrf;
    showView('home');
    showToast('Sesión cerrada.');
    return;
  }
  const trigger = event.target.closest('[data-view]');
  if (trigger) {
    event.preventDefault();
    showView(trigger.dataset.view);
  }
  const scrollTrigger = event.target.closest('[data-scroll]');
  if (scrollTrigger) {
    event.preventDefault();
    showView('home');
    window.setTimeout(() => document.getElementById(scrollTrigger.dataset.scroll)?.scrollIntoView({ behavior: 'smooth' }), 50);
  }
  const panelTrigger = event.target.closest('[data-scroll-panel]');
  if (panelTrigger) document.getElementById(panelTrigger.dataset.scrollPanel)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  if (event.target.closest('#pay-button, #certificate-button, .save-grade, .approve-button')) {
    showToast('Este módulo todavía está en desarrollo. No se realizó ninguna operación.');
  }
});

document.getElementById('login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  setBusy(form, true);
  try {
    const result = await api('/api/auth/login', { method: 'POST', body: JSON.stringify({
      email: value('login-email'), password: document.getElementById('login-password').value
    }) });
    csrfToken = result.csrf;
    form.reset();
    await enterPortal(result.user);
    showToast(`Bienvenido, ${result.user.first_name}.`);
  } catch (error) { showToast(error.message); }
  finally { setBusy(form, false); }
});

document.getElementById('register-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  setBusy(form, true);
  try {
    const result = await api('/api/auth/register', { method: 'POST', body: JSON.stringify({
      first_name: value('register-first-name'), last_name: value('register-last-name'),
      email: value('register-email'), document_type: value('register-doc-type'),
      document_number: value('register-doc-number'), password: document.getElementById('register-password').value
    }) });
    csrfToken = result.csrf;
    form.reset();
    await enterPortal(result.user);
    showToast('Cuenta creada y guardada en la base de datos.');
  } catch (error) { showToast(error.message); }
  finally { setBusy(form, false); }
});

function disableUnfinishedStudentModules() {
  const docs = document.getElementById('documents-panel');
  docs.innerHTML = '<span class="eyebrow">Próxima etapa</span><h3>Documentos</h3><p class="muted">La carga y revisión segura de documentos estará disponible en una siguiente actualización. No envíes archivos personales todavía.</p>';
  document.querySelector('.payment-row').innerHTML = '<div class="panel"><span class="eyebrow">Próxima etapa</span><h3>Pagos y matrícula</h3><p class="muted">Los pagos y comprobantes no están habilitados. El sistema no cobra dinero ni emite matrículas reales.</p></div>';
  const schedule = document.querySelector('#enrollment-panel .workflow-card:nth-child(2)');
  schedule.querySelector('h3').textContent = 'Materias seleccionadas';
  const scheduleTable = schedule.querySelector('table');
  if (scheduleTable) {
    const message = document.createElement('p');
    message.className = 'muted';
    message.textContent = 'La asignación de horarios se habilitará más adelante. Por ahora se guarda tu elección preliminar de materias.';
    scheduleTable.replaceWith(message);
  }
  schedule.querySelector('.save-enrollment').textContent = 'Guardar carrera y materias';
}

async function populateStudent(user) {
  document.querySelector('#student-view .dashboard-top h1').textContent = `Hola, ${user.first_name} 👋`;
  document.getElementById('student-mini-name').textContent = `${user.first_name} ${user.last_name}`;
  document.getElementById('student-mini-avatar').textContent = initials(user);
  document.querySelector('#student-view .avatar').textContent = initials(user);
  disableUnfinishedStudentModules();
  try {
    const { enrollment } = await api('/api/enrollment');
    const hasEnrollment = Boolean(enrollment);
    document.querySelector('.progress-panel .panel-title span').textContent = hasEnrollment ? '50%' : '0%';
    document.querySelector('.progress-panel .progress i').style.width = hasEnrollment ? '50%' : '0%';
    document.querySelector('.status-panel h3').textContent = hasEnrollment ? 'Borrador guardado' : 'Sin inscripción';
    document.querySelector('.status-panel p').textContent = hasEnrollment ? 'Tu carrera y materias están guardadas.' : 'Elige una carrera para comenzar.';
    document.querySelector('.alert-banner strong').textContent = hasEnrollment ? 'Tu inscripción se guardó correctamente' : 'Comienza tu inscripción';
    document.querySelector('.alert-banner p').textContent = hasEnrollment ? 'Podrás continuar cuando se habiliten los siguientes módulos.' : 'Selecciona tu carrera y las materias que deseas cursar.';
    document.querySelector('.progress-items').innerHTML = hasEnrollment
      ? '<div class="done">✓ <span>Cuenta creada</span></div><div class="done">✓ <span>Materias guardadas</span></div><div>3 <span>Documentos (próximamente)</span></div><div>4 <span>Confirmación (próximamente)</span></div>'
      : '<div class="done">✓ <span>Cuenta creada</span></div><div>2 <span>Elegir carrera y materias</span></div><div>3 <span>Documentos (próximamente)</span></div><div>4 <span>Confirmación (próximamente)</span></div>';
    if (enrollment) {
      document.getElementById('program-select').value = enrollment.career;
      document.querySelectorAll('.subject-list input').forEach(input => { input.checked = enrollment.subjects.includes(input.closest('label').textContent.trim()); });
    }
  } catch (error) { showToast(error.message); }
}

document.querySelector('.save-enrollment').addEventListener('click', async (event) => {
  if (!currentUser || currentUser.role !== 'student') return;
  const button = event.currentTarget;
  button.disabled = true;
  const subjects = [...document.querySelectorAll('.subject-list label')]
    .filter(label => label.querySelector('input').checked)
    .map(label => label.textContent.trim());
  try {
    await api('/api/enrollment', { method: 'PUT', body: JSON.stringify({
      career: document.getElementById('program-select').value, subjects
    }) });
    await populateStudent(currentUser);
    showToast('Carrera y materias guardadas en PostgreSQL.');
  } catch (error) { showToast(error.message); }
  finally { button.disabled = false; }
});

function populateTeacher(user) {
  const content = document.querySelector('#teacher-view .dashboard-content');
  content.replaceChildren();
  const header = document.createElement('div');
  header.className = 'dashboard-top';
  const heading = document.createElement('h1');
  heading.textContent = `Bienvenido, ${user.first_name}`;
  header.append(heading);
  const panel = document.createElement('div');
  panel.className = 'panel';
  panel.innerHTML = '<span class="eyebrow">Portal docente</span><h3>Calificaciones: próxima etapa</h3><p class="muted">El acceso docente ya tiene autenticación por rol. Las notas y materias se habilitarán cuando implementemos este módulo.</p>';
  content.append(header, panel);
}

const newRole = document.getElementById('new-user-role');
newRole.addEventListener('change', () => {
  const role = newRole.value;
  const title = document.getElementById('dynamic-field-title');
  const input = document.getElementById('new-user-extra');
  if (role === 'ESTUDIANTE') { title.textContent = 'Carrera a postular:'; input.placeholder = 'Ej. Medicina'; }
  else if (role === 'DOCENTE') { title.textContent = 'Especialidad:'; input.placeholder = 'Ej. Matemática'; }
  else { title.textContent = 'Cargo:'; input.placeholder = 'Ej. Encargado de admisiones'; }
});

async function populateAdmin(user) {
  document.getElementById('admin-greeting').textContent = `Hola, ${user.first_name} 👋`;
  document.getElementById('admin-user-name').textContent = `${user.first_name} ${user.last_name}`;
  document.getElementById('admin-user-role').textContent = 'Administración';
  document.getElementById('admin-user-avatar').textContent = initials(user);
  document.getElementById('admin-top-avatar').textContent = initials(user);
  document.getElementById('admin-docs-section').innerHTML = '<div class="panel-title"><h3>Revisión de documentos</h3></div><p class="muted">Módulo pendiente: todavía no se aceptan archivos ni se validan documentos reales.</p>';
  try {
    const [stats, result] = await Promise.all([api('/api/admin/stats'), api('/api/admin/users')]);
    const numbers = [...document.querySelectorAll('.admin-stats .panel strong')];
    numbers[0].textContent = stats.enrollments;
    numbers[1].textContent = stats.pending;
    numbers[2].textContent = stats.approved;
    numbers[3].textContent = stats.users;
    document.querySelectorAll('.admin-stats .panel small').forEach((label) => { label.textContent = 'Datos actuales'; });
    document.getElementById('user-count-badge').textContent = `${stats.users} usuarios registrados`;
    const body = document.getElementById('users-table-body');
    body.replaceChildren();
    for (const record of result.users) {
      const tr = document.createElement('tr');
      const cells = [`${record.first_name} ${record.last_name}`, record.email,
        `${record.document_number} ${record.document_type}`, record.role.toUpperCase(), record.detail || '—', 'Activo'];
      for (const cell of cells) {
        const td = document.createElement('td'); td.textContent = cell; tr.append(td);
      }
      body.append(tr);
    }
  } catch (error) { showToast(error.message); }
}

document.getElementById('create-user-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  setBusy(form, true);
  try {
    await api('/api/admin/users', { method: 'POST', body: JSON.stringify({
      role: value('new-user-role').toLowerCase(), first_name: value('new-user-nombres'),
      last_name: value('new-user-apellidos'), email: value('new-user-email'),
      document_type: 'CI', document_number: value('new-user-ci'),
      detail: value('new-user-extra'), password: document.getElementById('new-user-password').value
    }) });
    form.reset();
    await populateAdmin(currentUser);
    showToast('Usuario creado y guardado correctamente.');
  } catch (error) { showToast(error.message); }
  finally { setBusy(form, false); }
});

// Parallax limitado a dispositivos con puntero preciso y sin reducción de movimiento.
const scene = document.getElementById('hero-scene');
if (window.matchMedia('(pointer: fine) and (prefers-reduced-motion: no-preference)').matches) {
  scene.addEventListener('pointermove', event => {
    const bounds = scene.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width - .5;
    const y = (event.clientY - bounds.top) / bounds.height - .5;
    scene.style.setProperty('--tilt-x', `${(-y * 7).toFixed(1)}deg`);
    scene.style.setProperty('--tilt-y', `${(x * 7).toFixed(1)}deg`);
  });
  scene.addEventListener('pointerleave', () => {
    scene.style.setProperty('--tilt-x', '0deg');
    scene.style.setProperty('--tilt-y', '0deg');
  });
}

(async function init() {
  try {
    csrfToken = (await api('/api/csrf')).csrf;
    const { user } = await api('/api/auth/me');
    await enterPortal(user);
  } catch (_) {
    // Un visitante sin sesión permanece en la portada. El login validará el backend.
    showView('home');
  }
})();
