document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-confirm]');
  if (el && !confirm(el.dataset.confirm)) e.preventDefault();
});
setTimeout(() => document.querySelectorAll('.flash').forEach(x => x.classList.add('hide')), 4500);
