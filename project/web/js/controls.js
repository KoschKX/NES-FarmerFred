function bindMobileControls(instance) {
  document.querySelectorAll('[data-btn]').forEach(btn => {
    const button = btn.dataset.btn
    const onDown = (e) => {
      e.preventDefault()
      btn.classList.add('pressed')
      instance.pressDown(button)
    }
    const onUp = (e) => {
      e.preventDefault()
      btn.classList.remove('pressed')
      instance.pressUp(button)
    }
    btn.addEventListener('touchstart',  onDown, { passive: false })
    btn.addEventListener('touchend',    onUp,   { passive: false })
    btn.addEventListener('touchcancel', onUp,   { passive: false })
    btn.addEventListener('mousedown',   onDown)
    btn.addEventListener('mouseup',     onUp)
    btn.addEventListener('mouseleave',  onUp)
  })
}
