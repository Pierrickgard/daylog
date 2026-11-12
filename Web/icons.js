// Inline icons (16px, stroke = currentColor).
const svg = (d) => `<svg viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

const svg24 = (d) => `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

const ICONS = {
  today: svg('<rect x="2.5" y="3.5" width="11" height="10" rx="1.5"/><path d="M2.5 6.5h11M5.5 2v3M10.5 2v3"/>'),
  todo: svg('<rect x="2.5" y="2.5" width="11" height="11" rx="2"/><path d="M5.5 8l2 2 3.5-4"/>'),
  template: svg('<path d="M4 2.5h5.5L12 5v8.5H4z"/><path d="M9.5 2.5V5H12M6 8h4M6 10.5h4"/>'),
  settings: svg24('<path d="M18.88 9.87L21.31 10.11L21.31 13.89L18.88 14.13L18.37 15.36L19.92 17.25L17.25 19.92L15.36 18.37L14.13 18.88L13.89 21.31L10.11 21.31L9.87 18.88L8.64 18.37L6.75 19.92L4.08 17.25L5.63 15.36L5.12 14.13L2.69 13.89L2.69 10.11L5.12 9.87L5.63 8.64L4.08 6.75L6.75 4.08L8.64 5.63L9.87 5.12L10.11 2.69L13.89 2.69L14.13 5.12L15.36 5.63L17.25 4.08L19.92 6.75L18.37 8.64Z"/><circle cx="12" cy="12" r="3"/>'),
  x: svg('<path d="M4.5 4.5l7 7M11.5 4.5l-7 7"/>'),
  check: svg('<path d="M3.5 8.5l3 3 6-7"/>'),
  caret: svg('<path d="M6 4l4 4-4 4"/>'),
};
