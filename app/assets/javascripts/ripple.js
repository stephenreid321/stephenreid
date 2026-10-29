// The homepage hero's background: a grid of small squares that ripples like water. A click drops a stone, dragging
// trails smaller ones, and a mouse gliding over it stirs it faintly. Colours come from the theme's --ripple-* properties
(function () {
  const hero = document.querySelector('.ripple-hero')
  const canvas = hero && hero.querySelector('canvas')
  if (!canvas) return
  const ctx = canvas.getContext('2d')

  const cell = 12 // px, including the gap
  const gap = 3
  const damping = 0.975
  const force = 5
  // The visible grid is a window onto a bigger pond: M hidden cells on each side, the outer SP of them a sponge that
  // soaks waves up gradually, so they travel off as if the water went on for ever
  const M = 48
  const SP = 32
  // Mur's open-boundary coefficient for this scheme's wave speed (1/sqrt(2) cells per step)
  const K = (Math.SQRT1_2 - 1) / (Math.SQRT1_2 + 1)

  let cols = 0
  let rows = 0
  let W = 0
  let H = 0
  let cur, prev, sponge // height buffers for the wave equation, and each cell's sponge damping
  let width = 0
  let height = 0

  // Reads a --ripple-* colour as [r, g, b]: the canvas turns any CSS colour it's given into #rrggbb
  function colour (name) {
    ctx.fillStyle = getComputedStyle(hero).getPropertyValue(name).trim()
    return ctx.fillStyle.match(/[0-9a-f]{2}/gi).map((h) => parseInt(h, 16))
  }
  const still = colour('--ripple-still')
  const crest = colour('--ripple-crest')
  const trough = colour('--ripple-trough')

  function resize () {
    const dpr = window.devicePixelRatio || 1
    // The observer also fires once on start, which mustn't wipe the first stone
    if (canvas.clientWidth === width && canvas.clientHeight === height) return
    width = canvas.clientWidth
    height = canvas.clientHeight
    canvas.width = Math.round(width * dpr)
    canvas.height = Math.round(height * dpr)
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    cols = Math.max(2, Math.ceil(width / cell))
    rows = Math.max(2, Math.ceil(height / cell))
    W = cols + 2 * M
    H = rows + 2 * M
    cur = new Float32Array(W * H)
    prev = new Float32Array(W * H)
    sponge = new Float32Array(W * H)
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const d = Math.min(x, y, W - 1 - x, H - 1 - y)
        sponge[y * W + x] = d < SP ? 1 - 0.15 * ((SP - d) / SP) ** 2 : 1
      }
    }
    draw()
  }

  // A small round splash
  function drop (px, py, strength) {
    const cx = Math.floor(px / cell)
    const cy = Math.floor(py / cell)
    const r = 2
    for (let dy = -r; dy <= r; dy++) {
      for (let dx = -r; dx <= r; dx++) {
        const x = cx + dx
        const y = cy + dy
        const d = Math.hypot(dx, dy)
        if (x < 0 || y < 0 || x >= cols || y >= rows || d > r) continue
        cur[(y + M) * W + x + M] += strength * 60 * (1 - d / (r + 1))
      }
    }
  }

  // A soft, rounded push, spread over a few cells so no single cell jumps
  function stir (px, py, amount) {
    const cx = px / cell - 0.5
    const cy = py / cell - 0.5
    const r = 3
    const s2 = 2 * 1.3 * 1.3
    for (let y = Math.ceil(cy - r); y <= Math.floor(cy + r); y++) {
      for (let x = Math.ceil(cx - r); x <= Math.floor(cx + r); x++) {
        if (x < 0 || y < 0 || x >= cols || y >= rows) continue
        cur[(y + M) * W + x + M] += amount * Math.exp(-((x - cx) ** 2 + (y - cy) ** 2) / s2)
      }
    }
  }

  // One step of the two-buffer ripple: new = avg(neighbours) * 2 - old, then damp
  function step () {
    for (let y = 1; y < H - 1; y++) {
      for (let x = 1; x < W - 1; x++) {
        const i = y * W + x
        prev[i] = ((cur[i - 1] + cur[i + 1] + cur[i - W] + cur[i + W]) / 2 - prev[i]) * damping * sponge[i]
      }
    }
    // The pond's outer edge lets what the sponge leaves pass out rather than bounce back
    const edge = (i, inner) => { prev[i] = cur[inner] + K * (prev[inner] - cur[i]) }
    for (let x = 1; x < W - 1; x++) {
      edge(x, x + W)
      edge((H - 1) * W + x, (H - 2) * W + x)
    }
    for (let y = 1; y < H - 1; y++) {
      edge(y * W, y * W + 1)
      edge(y * W + W - 1, y * W + W - 2)
    }
    [cur, prev] = [prev, cur]
  }

  const mix = (a, b, t) => a.map((v, i) => (v + (b[i] - v) * t) | 0)

  function draw () {
    ctx.clearRect(0, 0, width, height)
    const size = cell - gap
    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const t = Math.max(-1, Math.min(1, cur[(y + M) * W + x + M] / 80))
        const q = Math.round(t * 24) / 24 // so similar cells share a fill
        ctx.fillStyle = `rgb(${q >= 0 ? mix(still, crest, q) : mix(still, trough, -q)})`
        ctx.fillRect(x * cell + gap / 2, y * cell + gap / 2, size, size)
      }
    }
  }

  // Hover: each frame, stir along the path the mouse took since the last one, in steps of half a cell. The push grows
  // with distance travelled, capped so a fast flick stays gentle, and while the mouse is moving, even very slowly, it
  // also gives a small steady push where it is
  let hoverAt = null
  let hoverFrom = null
  let hoverMoved = 0
  let dragging = false
  let lastDrag = 0
  function stirHover () {
    if (dragging || !hoverAt) return
    const [x1, y1] = hoverAt
    const [x0, y0] = hoverFrom || hoverAt
    hoverFrom = hoverAt
    if (performance.now() - hoverMoved < 150) stir(x1, y1, force * 0.15)
    const dist = Math.hypot(x1 - x0, y1 - y0) / cell
    if (dist < 0.05) return
    const n = Math.ceil(dist * 2)
    const per = (Math.min(dist, 3) / n) * force * 0.6
    for (let i = 1; i <= n; i++) stir(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, per)
  }

  const local = (e) => {
    const r = canvas.getBoundingClientRect()
    return [e.clientX - r.left, e.clientY - r.top]
  }

  resize()
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return

  // The pointer events are on the hero, so the water still responds under its text and picture
  hero.addEventListener('pointerdown', (e) => {
    dragging = true
    drop(...local(e), force)
  })
  hero.addEventListener('pointermove', (e) => {
    if (!dragging) {
      if (e.pointerType !== 'touch') {
        hoverAt = local(e)
        hoverMoved = performance.now()
      }
      return
    }
    if (e.timeStamp - lastDrag < 30) return
    lastDrag = e.timeStamp
    drop(...local(e), force * 0.4)
  })
  const stop = () => { dragging = false }
  window.addEventListener('pointerup', stop)
  window.addEventListener('pointercancel', stop)
  hero.addEventListener('pointerleave', () => { hoverAt = hoverFrom = null })
  new ResizeObserver(resize).observe(canvas)

  // Animate only while the hero is on screen
  let visible = true
  let running = false
  function loop () {
    if (!visible) {
      running = false
      return
    }
    stirHover()
    step()
    draw()
    requestAnimationFrame(loop)
  }
  function start () {
    if (running) return
    running = true
    requestAnimationFrame(loop)
  }
  new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting
    if (visible) start()
  }).observe(hero)

  // Start with a stone dropped in the middle, so the hero ripples as the page opens
  drop(width / 2, height / 2, force)
  start()
})()
