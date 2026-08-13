function ChildTabs({ activeChild, setActiveChild }) {
  return (
    <div className="child-tabs">
      {window.DATA.parent.children.map((c, i) => (
        <button key={c.id} className={"child-tab" + (i === activeChild ? " active" : "")} onClick={() => setActiveChild(i)}>
          <div className="avatar" style={{ width: 28, height: 28, fontSize: 12 }}>{c.initials}</div>
          <div className="col" style={{ alignItems: 'flex-start' }}>
            <span style={{ fontWeight: 700, fontSize: 13 }}>{c.name}</span>
          </div>
        </button>
      ))}
    </div>
  );
}

function ParentOverview({ activeChild, setActiveChild }) {
  const c = window.DATA.parent.children[activeChild];
  const activity = [
    { icon: 'sparkles', text: 'Asked the AI Tutor about fractions', time: '2h ago' },
    { icon: 'book', text: 'Completed "The water cycle" lesson', time: 'Yesterday' },
    { icon: 'pen', text: 'Solved 4 problems in the Workbook', time: 'Yesterday' },
    { icon: 'checkCircle', text: 'Passed a quick check in Mathematics', time: '2 days ago' },
  ];
  return (
    <div className="col gap-16">
      <ChildTabs activeChild={activeChild} setActiveChild={setActiveChild} />
      <div className="row gap-12">
        <div className="stat-tile"><div className="val">{c.minutes}</div><div className="faint" style={{ fontSize: 12.5 }}>minutes this week</div></div>
        <div className="stat-tile"><div className="val">{c.questions}</div><div className="faint" style={{ fontSize: 12.5 }}>questions asked</div></div>
        <div className="stat-tile"><div className="val">{c.streak}d</div><div className="faint" style={{ fontSize: 12.5 }}>current streak</div></div>
      </div>
      <div className="card col gap-8">
        <div className="row gap-8" style={{ fontWeight: 700, fontSize: 14 }}><Icon name="info" size={16} />Needs a little attention</div>
        {c.attention.map((a, i) => <div key={i} className="chip chip-warning" style={{ alignSelf: 'flex-start' }}>{a}</div>)}
      </div>
      <div className="col gap-8">
        <div className="section-title">Recent activity</div>
        <div className="card" style={{ padding: '4px 16px' }}>
          {activity.map((a, i) => (
            <div key={i} className="list-row">
              <div className="icon-tile" style={{ background: 'var(--surface-sunken)' }}><Icon name={a.icon} size={16} /></div>
              <div style={{ flex: 1, fontSize: 13.5 }}>{a.text}</div>
              <div className="faint" style={{ fontSize: 12 }}>{a.time}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="trust-banner">
        <div className="icon-tile"><Icon name="cloudOff" size={18} /></div>
        <div className="col gap-4">
          <div style={{ fontWeight: 700, fontSize: 14 }}>Works without internet</div>
          <div className="muted" style={{ fontSize: 13 }}>{c.name.split(' ')[0]}'s lessons keep working through outages — progress syncs automatically once back online.</div>
        </div>
      </div>
    </div>
  );
}

function ParentReports({ activeChild, setActiveChild }) {
  const c = window.DATA.parent.children[activeChild];
  return (
    <div className="col gap-16">
      <ChildTabs activeChild={activeChild} setActiveChild={setActiveChild} />
      <div className="card col gap-10">
        <div className="row between"><div className="section-title">This week's report</div><button className="btn btn-soft btn-sm"><Icon name="download" size={14} />PDF</button></div>
        {window.DATA.progress.subjects.map(s => (
          <div key={s.name} className="col gap-4">
            <div className="row between" style={{ fontSize: 13.5 }}><span style={{ fontWeight: 600 }}>{s.name}</span><span className="faint">{s.mastery}%</span></div>
            <div className="bar-track"><div className="bar-fill" style={{ width: s.mastery + '%', background: `var(--${s.color})` }} /></div>
          </div>
        ))}
      </div>
      <div className="muted" style={{ fontSize: 13 }}>Reports show mastery trends, not every wrong answer — so you can encourage without piling on pressure.</div>
    </div>
  );
}

function ParentMessages() {
  const [msgs, setMsgs] = React.useState(window.DATA.parent.messages);
  const [text, setText] = React.useState('');
  const endRef = React.useRef(null);
  React.useEffect(() => { endRef.current && endRef.current.scrollIntoView({ behavior: 'smooth' }); }, [msgs]);
  function send() { if (!text.trim()) return; setMsgs(m => [...m, { from: 'You', text, me: true, time: 'Now' }]); setText(''); }
  return (
    <div className="col" style={{ height: '100%' }}>
      <div className="col gap-10" style={{ flex: 1, overflow: 'auto' }}>
        {msgs.map((m, i) => (
          <div key={i} className="col" style={{ alignItems: m.me ? 'flex-end' : 'flex-start' }}>
            <div className={"msg-bubble " + (m.me ? "me" : "them")}>{m.text}</div>
            <div className="faint" style={{ fontSize: 11, marginTop: 2 }}>{m.from} · {m.time}</div>
          </div>
        ))}
        <div ref={endRef} />
      </div>
      <div className="composer">
        <input className="input" placeholder="Message the class teacher…" value={text} onChange={e => setText(e.target.value)} onKeyDown={e => e.key === 'Enter' && send()} />
        <button className="send-btn" onClick={send} disabled={!text.trim()}><Icon name="send" size={16} /></button>
      </div>
    </div>
  );
}

function ParentBilling() {
  const plan = window.DATA.parent.plan;
  const [added, setAdded] = React.useState(null);
  return (
    <div className="col gap-16">
      <div className="trust-banner">
        <div className="icon-tile"><Icon name="shield" size={18} /></div>
        <div className="col gap-4">
          <div style={{ fontWeight: 700, fontSize: 14 }}>Included in {plan.school}'s EduAI plan</div>
          <div className="muted" style={{ fontSize: 13 }}>No extra cost to you — the school covers full access for every enrolled student. Renews {plan.renews}.</div>
        </div>
      </div>
      <div className="card row gap-16">
        <div className="col gap-2" style={{ flex: 1 }}><div className="faint" style={{ fontSize: 12 }}>Plan</div><div style={{ fontWeight: 700 }}>{plan.tier}</div></div>
        <div className="col gap-2" style={{ flex: 1 }}><div className="faint" style={{ fontSize: 12 }}>Students covered</div><div style={{ fontWeight: 700 }}>{plan.seats}</div></div>
        <div className="col gap-2" style={{ flex: 1 }}><div className="faint" style={{ fontSize: 12 }}>Renews</div><div style={{ fontWeight: 700 }}>{plan.renews}</div></div>
      </div>
      <div className="col gap-10">
        <div className="section-title">Want more AI Tutor sessions?</div>
        <div className="muted" style={{ fontSize: 13 }}>Optional top-ups, paid by Mobile Money — never required to keep learning.</div>
        <div className="row gap-12" style={{ flexWrap: 'wrap' }}>
          {window.DATA.parent.topups.map(t => (
            <div key={t.label} className={"pricing-card" + (added === t.label ? " reco" : "")} style={{ flex: '1 1 150px' }}>
              <div style={{ fontWeight: 700, fontSize: 13.5 }}>{t.label}</div>
              <div className="price">{t.price} RWF</div>
              <div className="faint" style={{ fontSize: 12.5, marginBottom: 10 }}>{t.sessions} extra sessions</div>
              <button className={"btn btn-sm btn-block " + (added === t.label ? "btn-outline" : "btn-primary")} onClick={() => setAdded(t.label)}>
                {added === t.label ? "Added ✓" : "Pay with MoMo"}
              </button>
            </div>
          ))}
        </div>
      </div>
      <div className="faint" style={{ fontSize: 12 }}>Your child's data stays private — never sold or used for advertising.</div>
    </div>
  );
}

window.ParentOverview = ParentOverview;
window.ParentReports = ParentReports;
window.ParentMessages = ParentMessages;
window.ParentBilling = ParentBilling;
