// Main window: sidebar + one page (today, a past day, to-do, template, settings).

let state = null;
let page = 'today';      // 'today' | 'todo' | 'template' | 'settings' | 'day:YYYY-MM-DD'
let editingRaw = false;  // day page shows the raw markdown instead of the rendered view

const $sidebar = document.getElementById('sidebar');
const $main = document.getElementById('main');

async function refresh() {
  state = await call('state');
  LANG = state.lang;
  document.documentElement.lang = LANG;
  renderSidebar();
  // Don't rebuild a page while the user is typing in it.
  const active = document.activeElement;
  if (active && $main.contains(active) && (active.tagName === 'TEXTAREA' || active.tagName === 'INPUT')) return;
  await renderPage();
}

function go(next) {
  if (next !== page) editingRaw = false;
  page = next;
  renderSidebar();
  renderPage();
  $main.scrollTop = 0;
}

window.daylogRefresh = refresh;
window.daylogGo = go;

// ---------- Sidebar ----------

function navItem(id, label, icon, badge) {
  return h('button.nav' + (page === id ? '.active' : ''), { onclick: () => go(id) },
    h('span.icon', { html: ICONS[icon] }), h('span.label', {}, label),
    badge ? h('span.badge', {}, badge) : null);
}

function renderSidebar() {
  const open = state.todos.filter((x) => !x.done).length;
  const past = state.days.filter((d) => d.key !== state.today);
  $sidebar.replaceChildren(
    h('div.brand', {}, h('span.brand-mark'), 'daylog'),
    h('nav', {},
      navItem('today', t('today'), 'today'),
      navItem('todo', t('todo'), 'todo', open || null)),
    h('div.group', {}, t('history')),
    h('nav.days', {}, past.length ? historyByMonth(past) : h('p.empty-hint', {}, t('noHistory'))),
    updateBanner(),
    h('div.sidebar-footer', {},
      h('button.quick-btn', { onclick: () => call('openQuickEntry') },
        h('span', {}, t('quickLog')), kbd(state.shortcut)),
      navItem('template', t('template'), 'template'),
      navItem('settings', t('settings'), 'settings')),
  );
}

// History grouped by month ("November 2026"). The latest month, and the one holding the open day, start expanded;
// the rest is remembered per viewer.

const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const dateOf = (key) => new Date(key + 'T12:00:00');
const monthLabel = (ym) => capitalize(new Intl.DateTimeFormat(LANG, { month: 'long', year: 'numeric' }).format(dateOf(ym + '-01')));
const dayLabel = (key) => capitalize(new Intl.DateTimeFormat(LANG, { weekday: 'short', day: 'numeric' }).format(dateOf(key)));

function monthState() {
  try { return JSON.parse(localStorage.getItem('months') || '{}'); } catch { return {}; }
}

function historyByMonth(days) {
  const months = new Map();
  for (const d of days) {
    const ym = d.key.slice(0, 7);
    if (!months.has(ym)) months.set(ym, []);
    months.get(ym).push(d);
  }
  const saved = monthState();
  const latest = [...months.keys()][0];
  const current = page.startsWith('day:') ? page.slice(4, 11) : null;

  return [...months].map(([ym, list]) => {
    const open = ym === current || (saved[ym] ?? ym === latest);
    const toggle = () => {
      const next = monthState();
      next[ym] = !open;
      try { localStorage.setItem('months', JSON.stringify(next)); } catch {}
      renderSidebar();
    };
    return h('div.month', {},
      h('button.month-header', { onclick: toggle },
        h('span.caret' + (open ? '.open' : ''), { html: ICONS.caret }),
        h('span.label', {}, monthLabel(ym)),
        h('span.month-count', {}, list.length)),
      open ? list.map((d) => h('button.nav.day' + (page === 'day:' + d.key ? '.active' : ''),
        { onclick: () => go('day:' + d.key), title: d.title }, dayLabel(d.key))) : null);
  });
}

function updateBanner() {
  const u = state.update;
  if (u.status !== 'available' && u.status !== 'installing') return h('span');
  return h('div.update-banner', {},
    h('div.update-title', {}, t('updateAvailable', u.version || '')),
    h('div.actions', {},
      h('button.primary.small', { disabled: u.status === 'installing', onclick: () => call('installUpdate') },
        u.status === 'installing' ? t('installing') : t('install')),
      h('button.link', { onclick: () => call('openReleases') }, t('releaseNotes'))));
}

// ---------- Pages ----------

async function renderPage() {
  if (page === 'todo') return renderTodo();
  if (page === 'template') return renderTemplate();
  if (page === 'settings') return renderSettings();
  const key = page === 'today' ? state.today : page.slice(4);
  return renderDay(key, page === 'today');
}

function pageHeader(title, subtitle, ...actions) {
  return h('header.page-header', {},
    h('div', {}, h('h1', {}, title), subtitle ? h('p.subtitle', {}, subtitle) : null),
    h('div.actions', {}, actions));
}

// Day: rendered sections with inline add / edit / delete, or raw markdown.

function parseDay(text) {
  const lines = text.split('\n');
  const intro = [];
  const sections = [];
  lines.forEach((line, i) => {
    if (line.startsWith('## ')) sections.push({ name: line.slice(3).trim(), items: [] });
    else if (line.startsWith('# ')) return;
    else if (line.trim()) {
      const bullet = line.match(/^\s*[-*]\s+(.*)$/);
      const item = { index: i, text: bullet ? bullet[1] : line.trim(), bullet: !!bullet };
      (sections.length ? sections[sections.length - 1].items : intro).push(item);
    }
  });
  return { lines, intro, sections };
}

async function renderDay(key, isToday) {
  const day = await call('readDay', { key });
  const save = async (text) => { await call('writeDay', { key, text }); };

  const header = pageHeader(isToday ? t('today') : day.title, isToday ? day.title : null,
    h('button.ghost', { onclick: () => { editingRaw = !editingRaw; renderPage(); } },
      editingRaw ? t('done') : t('editMarkdown')),
    h('button.ghost', { onclick: () => call('reveal', { key }) }, t('showInFinder')));

  if (editingRaw) {
    const area = h('textarea.editor', { value: day.text, spellcheck: false });
    let timer;
    area.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => save(area.value), 300); });
    $main.replaceChildren(h('div.page.wide', {}, header, area));
    area.focus();
    return;
  }

  const { lines, intro, sections } = parseDay(day.text);
  const rewrite = async (fn) => { fn(lines); await save(lines.join('\n')); refresh(); };

  const entry = (item) => {
    const text = h('span.text', { html: inlineMarkdown(item.text), title: t('rename') });
    const li = h('li' + (item.bullet ? '' : '.plain'), {}, text,
      h('button.icon-btn', { title: '×', html: ICONS.x,
        onclick: () => rewrite((l) => l.splice(item.index, 1)) }));
    text.addEventListener('dblclick', () => {
      const input = h('input.inline-edit', { value: item.text });
      const commit = () => {
        const v = input.value.trim();
        if (!v) return rewrite((l) => l.splice(item.index, 1));
        if (v === item.text) return renderPage();
        rewrite((l) => { l[item.index] = item.bullet ? '- ' + v : v; });
      };
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') commit();
        if (e.key === 'Escape') renderPage();
      });
      input.addEventListener('blur', commit);
      text.replaceWith(input);
      input.focus();
    });
    return li;
  };

  const sectionBlock = (s) => {
    const input = h('input.add', { placeholder: t('addTo', s.name) });
    input.addEventListener('keydown', async (e) => {
      if (e.key !== 'Enter' || !input.value.trim()) return;
      await call('addLog', { key, section: s.name, text: input.value.trim() });
      await refresh();
      const again = [...$main.querySelectorAll('input.add')].find((x) => x.dataset.section === s.name);
      again && again.focus();
    });
    input.dataset.section = s.name;
    return h('section.day-section' + (s.items.length ? '' : '.empty'), {},
      h('h2', {}, s.name, s.items.length ? h('span.count', {}, s.items.length) : null),
      s.items.length ? h('ul', {}, s.items.map(entry)) : null,
      input);
  };

  const welcome = isToday && state.welcome ? h('div.welcome', {},
    h('h3', {}, t('welcomeTitle')),
    h('p', {}, welcomeSentence()),
    h('div.actions', {},
      h('button.primary', { onclick: () => call('openQuickEntry') }, t('tryIt')),
      h('button.ghost', { onclick: async () => { await call('dismissWelcome'); refresh(); } }, t('gotIt')))) : null;

  $main.replaceChildren(h('div.page', {},
    header,
    welcome,
    intro.length ? h('ul.intro', {}, intro.map(entry)) : null,
    sections.map(sectionBlock)));
}

function welcomeSentence() {
  // "Press [⌃][⌥][N] in any app…" followed by the spelled-out keys.
  const [before, after] = (STRINGS[LANG] || STRINGS.en).welcomeBody.split('{0}');
  return [h('span', {}, before), kbd(state.shortcut), h('span', {}, after + ' '),
    h('span.muted', {}, t('welcomeKeys', spellShortcut(state.shortcut)))];
}

// To-do

function renderTodo() {
  const open = state.todos.filter((x) => !x.done);
  const done = state.todos.filter((x) => x.done);
  const showDone = localStorage.getItem('showDone') !== '0';

  const add = h('input.big-input', { placeholder: t('newTask') });
  add.addEventListener('keydown', async (e) => {
    if (e.key !== 'Enter' || !add.value.trim()) return;
    await call('addTodo', { text: add.value.trim() });
    add.value = '';
    await refresh();
    $main.querySelector('input.big-input').focus();
  });

  const row = (item) => {
    const text = h('span.text', { html: inlineMarkdown(item.text), title: t('rename') });
    text.addEventListener('dblclick', () => {
      const input = h('input.inline-edit', { value: item.text });
      const commit = async () => {
        const v = input.value.trim();
        if (v && v !== item.text) await call('renameTodo', { id: item.id, text: v });
        refresh();
      };
      input.addEventListener('keydown', (e) => { if (e.key === 'Enter') input.blur(); if (e.key === 'Escape') refresh(); });
      input.addEventListener('blur', commit);
      text.replaceWith(input);
      input.focus();
    });
    return h('li.todo' + (item.done ? '.done' : ''), {},
      h('button.check', { 'aria-label': 'toggle', html: item.done ? ICONS.check : '',
        onclick: async () => { await call('setTodoDone', { id: item.id, done: !item.done }); refresh(); } }),
      text,
      h('button.icon-btn', { html: ICONS.x, onclick: async () => { await call('deleteTodo', { id: item.id }); refresh(); } }));
  };

  $main.replaceChildren(h('div.page', {},
    pageHeader(t('todo'), `${open.length} ${t('open')}`),
    add,
    open.length ? h('ul.todos', {}, open.map(row)) : h('p.empty-hint', {}, t('noTasks')),
    done.length ? h('div.done-header', {},
      h('button.link', { onclick: () => { localStorage.setItem('showDone', showDone ? '0' : '1'); renderPage(); } },
        h('span.caret' + (showDone ? '.open' : ''), { html: ICONS.caret }), `${t('doneCount')} · ${done.length}`),
      h('button.ghost.small', { onclick: async () => { await call('clearDoneTodos'); refresh(); } }, t('clearDone'))) : null,
    done.length && showDone ? h('ul.todos', {}, done.map(row)) : null));
}

// Template

async function renderTemplate() {
  const text = await call('readTemplate');
  const status = h('span.status');
  const area = h('textarea.editor', { value: text, spellcheck: false });
  let timer;
  area.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      await call('writeTemplate', { text: area.value });
      status.textContent = t('saved');
      setTimeout(() => (status.textContent = ''), 1200);
    }, 300);
  });
  $main.replaceChildren(h('div.page.wide', {},
    pageHeader(t('template'), null, status),
    h('p.help', {}, t('templateHelp')),
    area));
}

// Settings

function renderSettings() {
  const shortcutBtn = h('button.ghost', {
    onclick: async () => {
      shortcutBtn.textContent = t('pressKeys');
      shortcutBtn.classList.add('recording');
      state = await call('recordShortcut');
      renderSidebar();
      renderSettings();
    },
  }, t('change'));

  const loginToggle = h('input', { type: 'checkbox', checked: state.launchAtLogin });
  const loginError = h('p.error');
  loginToggle.addEventListener('change', async () => {
    const res = await call('setLaunchAtLogin', { on: loginToggle.checked });
    loginError.textContent = res.ok ? '' : res.error;
    if (!res.ok) loginToggle.checked = !loginToggle.checked;
  });

  const setting = (title, help, control, extra) => h('div.setting', {},
    h('div.setting-text', {}, h('div.setting-title', {}, title), h('div.setting-help', {}, help), extra),
    h('div.setting-control', {}, control));

  $main.replaceChildren(h('div.page', {},
    pageHeader(t('settings')),
    h('div.settings', {},
      setting(t('theme'), t('themeHelp'),
        h('div.segmented', {}, [['system', t('themeSystem')], ['light', t('themeLight')], ['dark', t('themeDark')]]
          .map(([id, label]) => h('button' + (state.theme === id ? '.on' : ''),
            { onclick: async () => { await call('setTheme', { theme: id }); refresh(); } }, label)))),
      setting(t('shortcut'), t('shortcutHelp'),
        [kbd(state.shortcut), shortcutBtn],
        state.shortcutOK ? null : h('p.error', {}, t('shortcutTaken'))),
      setting(t('folder'), t('folderHelp'),
        [h('button.ghost', { onclick: () => call('reveal', { key: '' }) }, t('openFolder')),
         h('button.ghost', { onclick: async () => { state = await call('chooseFolder'); refresh(); } }, t('change'))],
        h('code.path', {}, state.folder)),
      setting(t('launchAtLogin'), t('launchHelp'), h('label.switch', {}, loginToggle, h('span')), loginError),
      setting(t('updates'), t('updatesHelp'),
        [updateButton(), h('label.switch', {}, updatesToggle(), h('span'))],
        updateStatus())),
    h('p.about', {}, t('aboutBody', state.version))));
}

function updatesToggle() {
  const input = h('input', { type: 'checkbox', checked: state.checkForUpdates });
  input.addEventListener('change', async () => { await call('setCheckForUpdates', { on: input.checked }); refresh(); });
  return input;
}

function updateButton() {
  const u = state.update;
  if (u.status === 'available') return h('button.primary.small', { onclick: () => call('installUpdate') }, t('install'));
  return h('button.ghost', { disabled: u.status === 'checking' || u.status === 'installing',
    onclick: () => call('checkUpdate') }, u.status === 'checking' ? t('checking') : t('checkNow'));
}

function updateStatus() {
  const u = state.update;
  if (u.status === 'upToDate') return h('p.ok', {}, t('upToDate'));
  if (u.status === 'available') return h('p.ok', {}, t('updateAvailable', u.version));
  if (u.status === 'installing') return h('p.ok', {}, t('installing'));
  if (u.status === 'failed') return h('p.error', {}, u.error);
  return null;
}

// ---------- Keyboard ----------

document.addEventListener('keydown', (e) => {
  if (!e.metaKey) return;
  if (e.code === 'Digit1') { e.preventDefault(); go('today'); }
  if (e.code === 'Digit2') { e.preventDefault(); go('todo'); }
});

refresh();
