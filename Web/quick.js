// Quick entry popup: pick Daily (and a section) or To-do, type one line, Return.

let qs = null;            // state from the native side
let kind = 'daily';       // 'daily' | 'todo'
let section = '';

const $box = document.getElementById('box');
const $kinds = document.getElementById('kinds');
const $sections = document.getElementById('sections');
const $input = document.getElementById('input');
const $hints = document.getElementById('hints');

function render() {
  $kinds.replaceChildren(
    ...[['daily', t('daily')], ['todo', t('todo')]].map(([k, label], i) =>
      h('button' + (kind === k ? '.on' : ''), { onclick: () => setKind(k) }, label, h('kbd', {}, '⌘' + (i + 1)))));

  $sections.hidden = kind !== 'daily';
  $sections.replaceChildren(...qs.sections.map((s) =>
    h('button.chip' + (s === section ? '.on' : ''), { onclick: () => { section = s; render(); $input.focus(); } }, s)));

  $input.placeholder = kind === 'daily' ? t('whatDidYouDo') : t('whatToDo');
  $hints.replaceChildren(
    h('span', {}, h('kbd', {}, '↵'), ' ', t('hintAdd')),
    kind === 'daily' && qs.sections.length > 1 ? h('span', {}, h('kbd', {}, '⇥'), ' ', t('hintSection')) : null,
    h('span', {}, h('kbd', {}, 'esc'), ' ', t('hintClose')));

  requestAnimationFrame(() => call('resizeQuickEntry', { height: $box.offsetHeight }));
}

function setKind(k) {
  kind = k;
  render();
  $input.focus();
}

window.quickOpen = async () => {
  qs = await call('state');
  LANG = qs.lang;
  kind = qs.lastKind === 'todo' ? 'todo' : 'daily';
  section = qs.sections.includes(qs.lastSection) ? qs.lastSection : (qs.sections[0] || '');
  $input.value = '';
  render();
  $input.focus();
};

async function submit() {
  const text = $input.value.trim();
  if (!text) return;
  if (kind === 'daily') await call('addLog', { section: section || 'Other', text });
  else await call('addTodo', { text, fromQuick: true });
  $input.value = '';
  call('closeQuickEntry');
}

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') { e.preventDefault(); call('closeQuickEntry'); }
  else if (e.key === 'Enter' && !e.isComposing) { e.preventDefault(); submit(); }
  else if (e.metaKey && e.code === 'Digit1') { e.preventDefault(); setKind('daily'); }
  else if (e.metaKey && e.code === 'Digit2') { e.preventDefault(); setKind('todo'); }
  else if (e.key === 'Tab' && kind === 'daily' && qs.sections.length) {
    e.preventDefault();
    const i = qs.sections.indexOf(section);
    const n = qs.sections.length;
    section = qs.sections[(i + (e.shiftKey ? n - 1 : 1)) % n];
    render();
  }
});

window.quickOpen();
