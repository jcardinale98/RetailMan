function mostrarAviso() {
    const toast = document.getElementById("toast");
    if (!toast) return;
    toast.classList.add("show");
    window.clearTimeout(window.retailmanToast);
    window.retailmanToast = window.setTimeout(() => {
        toast.classList.remove("show");
    }, 2200);
}
