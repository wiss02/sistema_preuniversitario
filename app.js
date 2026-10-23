const views = ['home', 'login', 'register', 'student', 'teacher', 'admin'];
const toast = document.getElementById('toast');

function showView(name) {
  views.forEach((view) => {
    const element = document.getElementById(`${view}-view`);
    if (element) element.classList.toggle('hidden', view !== name);
  });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  window.setTimeout(() => toast.classList.remove('show'), 3500);
}

document.addEventListener('click', (event) => {
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
});

document.getElementById('login-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const role = document.getElementById('login-role').value;
  const email = document.getElementById('login-email').value.trim().toLowerCase();
  
  if (role === 'admin') {
    if (email === 'wilson@hotmail.com') {
      document.getElementById('admin-greeting').innerHTML = 'Hola, Wilson <em>👋</em>';
      document.getElementById('admin-user-name').textContent = 'Wilson';
      document.getElementById('admin-user-role').textContent = 'Administrador Principal';
      document.getElementById('admin-user-avatar').textContent = 'WA';
      document.getElementById('admin-top-avatar').textContent = 'WA';
      showToast('¡Bienvenido Administrador Wilson!');
    } else {
      document.getElementById('admin-greeting').innerHTML = 'Hola, Andrea <em>👋</em>';
      document.getElementById('admin-user-name').textContent = 'Andrea Méndez';
      document.getElementById('admin-user-role').textContent = 'Encargada de Admisiones';
      document.getElementById('admin-user-avatar').textContent = 'AM';
      document.getElementById('admin-top-avatar').textContent = 'AM';
      showToast('Inicio de sesión como Encargada.');
    }
  } else {
    showToast('Inicio de sesión exitoso.');
  }

  showView(role);
});

// Manejo dinámico del rol al crear nuevos usuarios
const newUserRoleSelect = document.getElementById('new-user-role');
if (newUserRoleSelect) {
  newUserRoleSelect.addEventListener('change', (e) => {
    const role = e.target.value;
    const title = document.getElementById('dynamic-field-title');
    const input = document.getElementById('new-user-extra');
    if (role === 'ESTUDIANTE') {
      title.textContent = 'Carrera a postular:';
      input.placeholder = 'Ej. Medicina / Ingeniería de Sistemas';
    } else if (role === 'DOCENTE') {
      title.textContent = 'Especialidad / Materia asignada:';
      input.placeholder = 'Ej. Matemática / Cálculo I';
    } else if (role === 'ADMIN') {
      title.textContent = 'Cargo / Área administrativa:';
      input.placeholder = 'Ej. Encargado de Admisiones / Auditor';
    }
  });
}

// Formulario de creación de nuevos usuarios
const createUserForm = document.getElementById('create-user-form');
if (createUserForm) {
  createUserForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const role = document.getElementById('new-user-role').value;
    const nombres = document.getElementById('new-user-nombres').value.trim();
    const apellidos = document.getElementById('new-user-apellidos').value.trim();
    const email = document.getElementById('new-user-email').value.trim();
    const ci = document.getElementById('new-user-ci').value.trim();
    const exp = document.getElementById('new-user-exp').value;
    const extra = document.getElementById('new-user-extra').value.trim();

    const iniciales = (nombres[0] || 'U') + (apellidos[0] || 'S');

    let roleBadge = '';
    if (role === 'ADMIN') {
      roleBadge = '<span class="table-status" style="background: #27372d; color: #c4e679;">ADMIN</span>';
    } else if (role === 'DOCENTE') {
      roleBadge = '<span class="table-status" style="background: #e1edf8; color: #205c90;">DOCENTE</span>';
    } else {
      roleBadge = '<span class="table-status" style="background: #f4faeb; color: #587d29;">ESTUDIANTE</span>';
    }

    const tbody = document.getElementById('users-table-body');
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><b>${nombres} ${apellidos}</b><small>${iniciales}</small></td>
      <td>${email}</td>
      <td>${ci} ${exp}</td>
      <td>${roleBadge}</td>
      <td>${extra}</td>
      <td><span class="table-status approved">Activo</span></td>
    `;
    tbody.prepend(tr);

    // Actualizar contador
    const totalStat = document.getElementById('total-users-stat');
    if (totalStat) {
      const current = parseInt(totalStat.textContent, 10) || 251;
      totalStat.textContent = current + 1;
    }

    createUserForm.reset();
    document.getElementById('new-user-password').value = '1234';
    showToast(`Usuario ${nombres} registrado exitosamente como ${role}.`);
  });
}

document.getElementById('register-form').addEventListener('submit', (event) => {
  event.preventDefault();
  showToast('Cuenta creada. Ahora puedes iniciar tu inscripción.');
  window.setTimeout(() => showView('student'), 700);
});

document.addEventListener('click', (event) => {
  const panelTrigger = event.target.closest('[data-scroll-panel]');
  if (panelTrigger) {
    document.getElementById(panelTrigger.dataset.scrollPanel)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  const saveEnrollment = event.target.closest('.save-enrollment');
  if (saveEnrollment) showToast('Materias y horario guardados correctamente.');

  const payButton = event.target.closest('#pay-button');
  if (payButton) {
    payButton.textContent = 'Pago registrado ✓';
    payButton.disabled = true;
    showToast('Pago registrado. Ya puedes generar tu matrícula.');
  }

  const certificateButton = event.target.closest('#certificate-button');
  if (certificateButton) showToast('Matrícula generada. Constancia lista para descargar.');

  const reviewButton = event.target.closest('.review-button');
  if (reviewButton) document.getElementById('review-form').classList.remove('hidden');

  const approveButton = event.target.closest('.approve-button');
  if (approveButton) {
    document.getElementById('review-form').classList.add('hidden');
    document.querySelector('.review-button').replaceWith(document.createTextNode('✓ Validado'));
    showToast('Documento validado y estudiante notificado.');
  }

  const saveGrade = event.target.closest('.save-grade');
  if (saveGrade) showToast('Nota guardada correctamente.');
});
