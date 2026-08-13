document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-confirm]');
  if (el && !confirm(el.dataset.confirm)) e.preventDefault();
});

setTimeout(() => document.querySelectorAll('.flash').forEach(x => x.classList.add('hide')), 4500);

function syncCategoryHierarchy() {
  const level = document.querySelector('[data-category-level]');
  const parent = document.querySelector('[data-category-parent]');
  if (!level || !parent) return;

  const refresh = () => {
    const value = Number(level.value || 0);
    if (value === 1) {
      parent.value = '';
      parent.disabled = true;
      parent.required = false;
    } else {
      parent.disabled = false;
      parent.required = value > 1;
    }
  };

  level.addEventListener('input', refresh);
  level.addEventListener('change', refresh);
  refresh();
}

document.addEventListener('DOMContentLoaded', syncCategoryHierarchy);