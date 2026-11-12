// Inline icons (16px, stroke = currentColor).
const svg = (d) => `<svg viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

const ICONS = {
  today: svg('<rect x="2.5" y="3.5" width="11" height="10" rx="1.5"/><path d="M2.5 6.5h11M5.5 2v3M10.5 2v3"/>'),
  todo: svg('<rect x="2.5" y="2.5" width="11" height="11" rx="2"/><path d="M5.5 8l2 2 3.5-4"/>'),
  template: svg('<path d="M4 2.5h5.5L12 5v8.5H4z"/><path d="M9.5 2.5V5H12M6 8h4M6 10.5h4"/>'),
  settings: svg('<circle cx="8" cy="8" r="2"/><path d="M8 1.8v1.6M8 12.6v1.6M14.2 8h-1.6M3.4 8H1.8M12.4 3.6l-1.1 1.1M4.7 11.3l-1.1 1.1M12.4 12.4l-1.1-1.1M4.7 4.7L3.6 3.6"/>'),
  x: svg('<path d="M4.5 4.5l7 7M11.5 4.5l-7 7"/>'),
  check: svg('<path d="M3.5 8.5l3 3 6-7"/>'),
  caret: svg('<path d="M6 4l4 4-4 4"/>'),
};
