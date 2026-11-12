// Shared helpers for the main window and the quick entry popup.

/** Calls the native side; resolves with its reply. */
const call = (cmd, args = {}) => window.webkit.messageHandlers.daylog.postMessage({ cmd, args });

const STRINGS = {
  en: {
    today: 'Today', todo: 'To-do', history: 'History', template: 'Daily template', settings: 'Settings',
    quickLog: 'Quick log', noHistory: 'Past days show up here.',
    editMarkdown: 'Edit markdown', done: 'Done', showInFinder: 'Show in Finder',
    addTo: 'Add to {0}…', emptySection: 'Nothing yet', notCreated: 'Nothing written yet today.',
    welcomeTitle: 'Log your day from anywhere',
    welcomeBody: 'Press {0} in any app to open the quick log, type what you just did and hit Return. It lands in today\'s note, under the section you picked.',
    welcomeKeys: 'That is {0}.', tryIt: 'Try it', gotIt: 'Got it',
    newTask: 'Add a task and press Return…', open: 'open', doneCount: 'Done', clearDone: 'Clear',
    noTasks: 'No tasks. Add one above, or with the quick log.', rename: 'Double-click to edit',
    templateHelp: 'New days start from this file. {{date}} becomes the date, and each "## " heading is a section you can pick in the quick log.',
    saved: 'Saved', shortcut: 'Quick log shortcut', shortcutHelp: 'Opens the quick log from any app.',
    change: 'Change', pressKeys: 'Press the new shortcut… (esc to cancel)',
    shortcutTaken: 'This shortcut is already used by another app. Pick another one.',
    folder: 'Notes folder', folderHelp: 'Plain Markdown files: one per day in daily/, plus todo.md.',
    openFolder: 'Open', launchAtLogin: 'Open at login', launchHelp: 'Start Daylog in the background when you log in.',
    about: 'About', aboutBody: 'Daylog {0} · open source, MIT license.',
    daily: 'Daily', whatDidYouDo: 'What did you just do?', whatToDo: 'What needs doing?',
    hintAdd: 'add', hintSection: 'section', hintClose: 'close', added: 'Added',
    keyNames: { '⌃': 'Control', '⌥': 'Option', '⇧': 'Shift', '⌘': 'Command' },
  },
  fr: {
    today: "Aujourd'hui", todo: 'To-do', history: 'Historique', template: 'Modèle du daily', settings: 'Réglages',
    quickLog: 'Ajout rapide', noHistory: 'Les jours passés apparaîtront ici.',
    editMarkdown: 'Modifier le markdown', done: 'Terminé', showInFinder: 'Afficher dans le Finder',
    addTo: 'Ajouter dans {0}…', emptySection: 'Rien pour l\'instant', notCreated: 'Rien d\'écrit aujourd\'hui.',
    welcomeTitle: 'Note ta journée depuis n\'importe où',
    welcomeBody: 'Appuie sur {0} dans n\'importe quelle app : l\'ajout rapide s\'ouvre, tu tapes ce que tu viens de faire et Entrée. Ça arrive dans la note du jour, sous la section choisie.',
    welcomeKeys: 'Soit {0}.', tryIt: 'Essayer', gotIt: 'Compris',
    newTask: 'Ajoute une tâche puis Entrée…', open: 'à faire', doneCount: 'Terminées', clearDone: 'Effacer',
    noTasks: 'Aucune tâche. Ajoutes-en une ci-dessus ou avec l\'ajout rapide.', rename: 'Double-clic pour modifier',
    templateHelp: 'Chaque nouveau jour part de ce fichier. {{date}} devient la date, et chaque titre « ## » est une section proposée dans l\'ajout rapide.',
    saved: 'Enregistré', shortcut: 'Raccourci d\'ajout rapide', shortcutHelp: 'Ouvre l\'ajout rapide depuis n\'importe quelle app.',
    change: 'Changer', pressKeys: 'Tape le nouveau raccourci… (esc pour annuler)',
    shortcutTaken: 'Ce raccourci est déjà pris par une autre app. Choisis-en un autre.',
    folder: 'Dossier des notes', folderHelp: 'Des fichiers Markdown : un par jour dans daily/, plus todo.md.',
    openFolder: 'Ouvrir', launchAtLogin: 'Ouvrir à la connexion', launchHelp: 'Lance Daylog en arrière-plan à l\'ouverture de session.',
    about: 'À propos', aboutBody: 'Daylog {0} · open source, licence MIT.',
    daily: 'Daily', whatDidYouDo: 'Qu\'est-ce que tu viens de faire ?', whatToDo: 'Qu\'est-ce qu\'il reste à faire ?',
    hintAdd: 'ajouter', hintSection: 'section', hintClose: 'fermer', added: 'Ajouté',
    keyNames: { '⌃': 'Contrôle', '⌥': 'Option', '⇧': 'Maj', '⌘': 'Commande' },
  },
};

let LANG = 'en';
const t = (key, ...args) => {
  const s = (STRINGS[LANG] && STRINGS[LANG][key]) ?? STRINGS.en[key] ?? key;
  return typeof s === 'string' ? s.replace(/\{(\d)\}/g, (_, i) => args[i] ?? '') : s;
};

/** "⌃⌥N" → "Control + Option + N" */
const spellShortcut = (label) => {
  const names = t('keyNames');
  const parts = [];
  let rest = label;
  while (rest && names[rest[0]]) { parts.push(names[rest[0]]); rest = rest.slice(1); }
  if (rest) parts.push(rest);
  return parts.join(' + ');
};

/** Tiny DOM builder: h('div.card', {onclick}, 'text', child) */
function h(tag, attrs = {}, ...children) {
  const [name, ...classes] = tag.split('.');
  const node = document.createElement(name || 'div');
  if (classes.length) node.className = classes.join(' ');
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else if (k === 'html') node.innerHTML = v;
    else if (k in node && k !== 'list') node[k] = v;
    else node.setAttribute(k, v);
  }
  for (const c of children.flat()) {
    if (c == null || c === false) continue;
    node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return node;
}

const escapeHTML = (s) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/** Inline markdown for one entry: `code`, **bold**, *italic*, links. */
const inlineMarkdown = (s) => escapeHTML(s)
  .replace(/`([^`]+)`/g, '<code>$1</code>')
  .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  .replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>')
  .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '<a href="$2">$1</a>')
  .replace(/(^|\s)(https?:\/\/[^\s<]+)/g, '$1<a href="$2">$2</a>');

/** Shortcut chip: "⌃⌥N" rendered as separate keys. */
const kbd = (label) => h('span.keys', {}, [...label.matchAll(/[⌃⌥⇧⌘]|.+$/gu)].map((m) => h('kbd', {}, m[0])));

document.addEventListener('click', (e) => {
  const a = e.target.closest('a[href^="http"]');
  if (a) { e.preventDefault(); call('openURL', { url: a.href }); }
});
