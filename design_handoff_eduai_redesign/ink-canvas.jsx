const InkCanvas = React.forwardRef(function InkCanvas({ height = 260, tool = 'pen', color = '#1a1b22', guide = 'plain', dark = false }, ref) {
  const canvasRef = React.useRef(null);
  const wrapRef = React.useRef(null);
  const strokesRef = React.useRef([]);
  const redoRef = React.useRef([]);
  const drawingRef = React.useRef(null);

  const sizeFor = (t) => t === 'highlighter' ? 16 : t === 'eraser' ? 20 : 3;

  function drawGuide(ctx, w, h) {
    ctx.save();
    ctx.strokeStyle = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.07)';
    ctx.lineWidth = 1;
    if (guide === 'lines') {
      for (let y = 32; y < h; y += 32) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
    } else if (guide === 'grid') {
      for (let x = 0; x < w; x += 24) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }
      for (let y = 0; y < h; y += 24) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
    }
    ctx.restore();
  }

  function redraw() {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    drawGuide(ctx, w, h);
    for (const s of strokesRef.current) paintStroke(ctx, s);
  }

  function paintStroke(ctx, s) {
    if (s.points.length < 2) return;
    ctx.save();
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    if (s.tool === 'eraser') { ctx.globalCompositeOperation = 'destination-out'; ctx.strokeStyle = 'rgba(0,0,0,1)'; }
    else { ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = s.color; ctx.globalAlpha = s.tool === 'highlighter' ? 0.35 : 1; }
    for (let i = 1; i < s.points.length; i++) {
      const a = s.points[i - 1], b = s.points[i];
      ctx.beginPath();
      ctx.lineWidth = Math.max(1.5, s.size * (0.6 + (b.p || 0.5)));
      ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
    }
    ctx.restore();
  }

  function toLocal(e) {
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width, scaleY = canvas.height / rect.height;
    return { x: (e.clientX - rect.left) * scaleX, y: (e.clientY - rect.top) * scaleY, p: e.pressure && e.pressure > 0 ? e.pressure : 0.5 };
  }

  function onDown(e) {
    e.preventDefault();
    const pt = toLocal(e);
    const stroke = { tool, color, size: sizeFor(tool), points: [pt] };
    drawingRef.current = stroke;
    strokesRef.current = [...strokesRef.current, stroke];
    redoRef.current = [];
    canvasRef.current.setPointerCapture && canvasRef.current.setPointerCapture(e.pointerId);
  }
  function onMove(e) {
    if (!drawingRef.current) return;
    drawingRef.current.points.push(toLocal(e));
    redraw();
  }
  function onUp() { drawingRef.current = null; }

  React.useImperativeHandle(ref, () => ({
    undo() { if (!strokesRef.current.length) return; const s = strokesRef.current.slice(); const last = s.pop(); strokesRef.current = s; redoRef.current = [...redoRef.current, last]; redraw(); },
    redo() { if (!redoRef.current.length) return; const r = redoRef.current.slice(); const last = r.pop(); redoRef.current = r; strokesRef.current = [...strokesRef.current, last]; redraw(); },
    clear() { strokesRef.current = []; redoRef.current = []; redraw(); },
    isEmpty() { return strokesRef.current.length === 0; },
  }));

  React.useEffect(() => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    const resize = () => {
      const rect = wrap.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = rect.width * dpr; canvas.height = height * dpr;
      canvas.getContext('2d').scale(dpr, dpr);
      redraw();
    };
    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, [guide]);

  return (
    <div ref={wrapRef} className="wb-canvas-wrap" style={{ height }}>
      <canvas ref={canvasRef} style={{ width: '100%', height: '100%', display: 'block', cursor: 'crosshair' }}
        onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerLeave={onUp} />
    </div>
  );
});
window.InkCanvas = InkCanvas;
