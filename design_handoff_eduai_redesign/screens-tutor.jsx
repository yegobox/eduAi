const SAMPLE_PROMPTS = ['Explain photosynthesis simply', 'Help me solve 2x + 5 = 11', 'What caused World War I?', 'Why is the sky blue?'];

function BlockView({ block, onFollowup }) {
  if (block.type === 'text') return <div className="block-text" dangerouslySetInnerHTML={{ __html: block.text.split('\n\n').map(p => '<p>' + p.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>') + '</p>').join('') }} />;
  if (block.type === 'example') return (
    <div className="block-example">
      <div className="row gap-8" style={{ marginBottom: 6, fontWeight: 700, fontSize: 13.5 }}><Icon name="lightbulb" size={16} />{block.title}</div>
      <div className="block-text" style={{ whiteSpace: 'pre-line' }}>{block.body}</div>
    </div>
  );
  if (block.type === 'check') return <CheckBlock block={block} />;
  if (block.type === 'followups') return (
    <div className="row gap-8" style={{ flexWrap: 'wrap' }}>
      {block.items.map((it, i) => <button key={i} className="prompt-chip" onClick={() => onFollowup(it)}>{it}</button>)}
    </div>
  );
  return null;
}

function CheckBlock({ block }) {
  const [sel, setSel] = React.useState(null);
  return (
    <div className="block-check">
      <div className="row gap-8" style={{ marginBottom: 8, fontWeight: 700, fontSize: 13.5 }}><Icon name="quiz" size={16} />Quick check</div>
      <div style={{ fontSize: 14.5, marginBottom: 4 }}>{block.question}</div>
      {block.choices.map((c, i) => (
        <div key={i} className={"choice-tile" + (sel !== null && i === block.correctIndex ? " correct" : sel === i && i !== block.correctIndex ? " wrong" : "")}
          onClick={() => sel === null && setSel(i)} style={{ cursor: sel === null ? 'pointer' : 'default' }}>
          <Icon name={sel !== null && i === block.correctIndex ? "checkCircle" : sel === i ? "cancel" : "grid"} size={16} />{c}
        </div>
      ))}
      {sel !== null && <div className="muted" style={{ fontSize: 13, marginTop: 8 }}>{block.explanation}</div>}
    </div>
  );
}

function TutorScreen() {
  const [messages, setMessages] = React.useState([]);
  const [input, setInput] = React.useState('');
  const [busy, setBusy] = React.useState(false);
  const [showPad, setShowPad] = React.useState(false);
  const padRef = React.useRef(null);
  const endRef = React.useRef(null);

  function send(text) {
    const t = (text || input).trim();
    if (!t || busy) return;
    setMessages(m => [...m, { role: 'user', text: t }]);
    setInput(''); setBusy(true);
    setTimeout(() => {
      const blocks = window.DATA.tutorSamples[t] || [{ type: 'text', text: "Let's break that down together. Can you tell me which part you're stuck on?" }, { type: 'followups', items: SAMPLE_PROMPTS.slice(0, 2) }];
      setMessages(m => [...m, { role: 'assistant', blocks }]);
      setBusy(false);
    }, 900);
  }

  React.useEffect(() => { endRef.current && endRef.current.scrollIntoView({ behavior: 'smooth' }); }, [messages, busy]);

  return (
    <div className="col" style={{ height: '100%' }}>
      <div className="col gap-12" style={{ flex: 1, overflow: 'auto' }}>
        {messages.length === 0 ? (
          <div className="chat-empty">
            <div className="icon-tile" style={{ width: 60, height: 60, borderRadius: 18 }}><Icon name="sparkles" size={26} /></div>
            <div style={{ fontWeight: 800, fontSize: 19 }}>Ask me anything you're studying</div>
            <div className="muted" style={{ fontSize: 14, maxWidth: 320 }}>I'll explain step by step and check your understanding along the way.</div>
            <div className="row gap-8" style={{ flexWrap: 'wrap', justifyContent: 'center', marginTop: 10 }}>
              {SAMPLE_PROMPTS.map(p => <button key={p} className="prompt-chip" onClick={() => send(p)}>{p}</button>)}
            </div>
          </div>
        ) : messages.map((m, i) => (
          <div key={i} className="col" style={m.role === 'user' ? { alignItems: 'flex-end' } : {}}>
            {m.role === 'user' ? <div className="bubble-user">{m.text}</div> : (
              <div className="col gap-8" style={{ maxWidth: '92%' }}>
                {m.blocks.map((b, j) => <BlockView key={j} block={b} onFollowup={send} />)}
              </div>
            )}
          </div>
        ))}
        {busy && <div className="thinking"><span className="dot-flash" /><span className="dot-flash" /><span className="dot-flash" />Thinking it through…</div>}
        <div ref={endRef} />
      </div>
      {showPad && (
        <div className="card-flat col gap-8" style={{ marginBottom: 8 }}>
          <div className="row between"><div style={{ fontWeight: 700, fontSize: 13 }}>Show your work</div><button className="icon-btn" onClick={() => setShowPad(false)}><Icon name="cancel" size={16} /></button></div>
          <InkCanvas ref={padRef} height={140} guide="grid" />
          <div className="row between">
            <button className="btn btn-outline btn-sm" onClick={() => padRef.current && padRef.current.clear()}>Clear</button>
            <button className="btn btn-primary btn-sm" onClick={() => { send('Can you check my handwritten working?'); setShowPad(false); }}>Attach &amp; ask</button>
          </div>
        </div>
      )}
      <div className="composer">
        <button className={"icon-btn" + (showPad ? " active" : "")} onClick={() => setShowPad(s => !s)} title="Show your work with a pen"><Icon name="pen" size={18} /></button>
        <input className="input" placeholder="Ask a question…" value={input} onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && send()} />
        <button className="send-btn" disabled={busy || !input.trim()} onClick={() => send()}><Icon name="send" size={16} /></button>
      </div>
    </div>
  );
}

function WorkbookScreen() {
  const [tool, setTool] = React.useState('pen');
  const [color, setColor] = React.useState('#1a1b22');
  const [guide, setGuide] = React.useState('grid');
  const [page, setPage] = React.useState(0);
  const [checked, setChecked] = React.useState(false);
  const ref = React.useRef(null);
  const colors = ['#1a1b22', '#4A54E8', '#D6455A', '#1E9D6C', '#B5720E'];
  const tools = [{ id: 'pen', icon: 'pen' }, { id: 'highlighter', icon: 'highlighter' }, { id: 'eraser', icon: 'trash' }];

  return (
    <div className="col gap-10" style={{ height: '100%' }}>
      <div className="row between">
        <div className="section-title">Workbook</div>
        <div className="wb-pages">
          {[0, 1, 2].map(p => <button key={p} className={"wb-page-tab" + (p === page ? " active" : "")} onClick={() => setPage(p)}>{p + 1}</button>)}
        </div>
      </div>
      <div className="wb-toolbar">
        {tools.map(t => <button key={t.id} className={"wb-tool" + (tool === t.id ? " active" : "")} onClick={() => setTool(t.id)}><Icon name={t.icon} size={17} /></button>)}
        <div style={{ width: 1, height: 24, background: 'var(--border)' }} />
        {colors.map(c => <button key={c} className={"wb-swatch" + (color === c ? " active" : "")} style={{ background: c }} onClick={() => { setColor(c); setTool('pen'); }} />)}
        <div style={{ width: 1, height: 24, background: 'var(--border)' }} />
        <div className="segmented">
          {['grid', 'lines', 'plain'].map(g => <button key={g} className={guide === g ? 'active' : ''} onClick={() => setGuide(g)}>{g}</button>)}
        </div>
        <div style={{ flex: 1 }} />
        <button className="icon-btn" onClick={() => ref.current && ref.current.undo()}><Icon name="undo" size={17} /></button>
        <button className="icon-btn" onClick={() => ref.current && ref.current.redo()}><Icon name="redo" size={17} /></button>
        <button className="icon-btn" onClick={() => { ref.current && ref.current.clear(); setChecked(false); }}><Icon name="trash" size={17} /></button>
      </div>
      <InkCanvas ref={ref} height={320} tool={tool} color={color} guide={guide} />
      {checked ? (
        <div className="wb-feedback">
          <Icon name="checkCircle" size={18} />
          <div className="col gap-4">
            <div style={{ fontWeight: 700, fontSize: 13.5 }}>Nice work — step 2 has a small slip</div>
            <div className="muted" style={{ fontSize: 13 }}>You subtracted correctly, but check the sign when you divide both sides by 2. Try it again on the next line.</div>
          </div>
        </div>
      ) : (
        <button className="btn btn-primary btn-block" onClick={() => setChecked(true)}><Icon name="sparkles" size={16} />Ask AI to check my work</button>
      )}
    </div>
  );
}

window.TutorScreen = TutorScreen;
window.WorkbookScreen = WorkbookScreen;
