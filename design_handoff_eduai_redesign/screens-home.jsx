function PinBanner() {
  const [dismissed, setDismissed] = React.useState(false);
  if (dismissed) return null;
  return (
    <div className="trust-banner" style={{ marginBottom: 16 }}>
      <div className="icon-tile"><Icon name="lock" size={18} /></div>
      <div className="col gap-6" style={{ flex: 1 }}>
        <div style={{ fontWeight: 700 }}>Set up offline access</div>
        <div className="muted" style={{ fontSize: 13.5 }}>Create a PIN so you can open EduAI without internet — school power cuts won't stop a lesson.</div>
      </div>
      <button className="btn btn-primary btn-sm" onClick={() => setDismissed(true)}>Set PIN</button>
    </div>
  );
}

function HomeScreen({ push }) {
  const school = window.DATA.schools[0];
  const features = [
    { id: 'tutor', icon: 'sparkles', title: 'AI Tutor', sub: 'Ask questions, get step-by-step help.' },
    { id: 'workbook', icon: 'pen', title: 'Workbook', sub: 'Solve by hand with a pen or stylus.' },
    { id: 'lessons', icon: 'book', title: 'Lessons', sub: 'REB-aligned, offline-ready content.' },
    { id: 'progress', icon: 'chart', title: 'Progress', sub: 'Track mastery over time.' },
  ];
  return (
    <div className="col gap-16">
      <div className="col gap-6">
        <div className="h1">Hello, {window.DATA.user.name} 👋</div>
        <div className="muted" style={{ fontSize: 15 }}>3-day streak — a little practice each day builds real mastery.</div>
      </div>
      <PinBanner />
      <div className="col gap-8">
        <div className="row between"><div className="section-title">My schools &amp; classes</div><button className="btn btn-soft btn-sm"><Icon name="search" size={14} />Browse</button></div>
        <div className="card" style={{ cursor: 'pointer' }} onClick={() => push({ title: school.name, data: school })}>
          <div className="list-row" style={{ padding: 0, border: 'none' }}>
            <div className="icon-tile" style={{ background: 'var(--brand-soft)', color: 'var(--brand)' }}><Icon name="school" size={18} /></div>
            <div className="col" style={{ flex: 1 }}>
              <div style={{ fontWeight: 700 }}>{school.name}</div>
              <div className="faint" style={{ fontSize: 13 }}>Class member • student</div>
            </div>
            <Icon name="chevronRight" size={18} />
          </div>
        </div>
      </div>
      <div className="col gap-8">
        <div className="section-title">Continue learning</div>
        <div className="lesson-grid">
          {features.map(f => (
            <div key={f.id} className="card lesson-card" onClick={() => window.dispatchEvent(new CustomEvent('nav-tab', { detail: f.id }))}>
              <div className="icon-tile" style={{ background: 'var(--brand-soft)', color: 'var(--brand)', marginBottom: 10 }}><Icon name={f.icon} size={18} /></div>
              <div style={{ fontWeight: 700, marginBottom: 4 }}>{f.title}</div>
              <div className="faint" style={{ fontSize: 13 }}>{f.sub}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function ClassroomDetailScreen({ sub }) {
  const school = sub.data;
  const [classes, setClasses] = React.useState(school.classes);
  const toggle = (id) => setClasses(cs => cs.map(c => c.id === id ? { ...c, joined: !c.joined } : c));
  return (
    <div className="col gap-16">
      <div className="muted">{school.desc}</div>
      <div className="card">
        <div className="list-row" style={{ padding: 0, border: 'none' }}>
          <div className="icon-tile" style={{ background: 'var(--brand-soft)', color: 'var(--brand)' }}><Icon name="users" size={18} /></div>
          <div className="col" style={{ flex: 1 }}>
            <div style={{ fontWeight: 700 }}>Join this school</div>
            <div className="faint" style={{ fontSize: 13 }}>Enrol to access this school and its classes.</div>
          </div>
          <button className="btn btn-primary btn-sm">Join</button>
        </div>
      </div>
      <div className="col gap-8">
        <div className="section-title">Classes</div>
        {classes.map(c => (
          <div key={c.id} className="card">
            <div className="list-row" style={{ padding: 0, border: 'none' }}>
              <div className="icon-tile" style={{ background: 'var(--surface-sunken)' }}><Icon name="book" size={18} /></div>
              <div className="col" style={{ flex: 1 }}>
                <div style={{ fontWeight: 700 }}>{c.name}</div>
                <div className="faint" style={{ fontSize: 13 }}>{c.grade}</div>
              </div>
              <button className={"btn btn-sm " + (c.joined ? "btn-outline" : "btn-primary")} onClick={() => toggle(c.id)}>{c.joined ? "Leave" : "Join"}</button>
            </div>
          </div>
        ))}
        <button className="btn btn-soft btn-block"><Icon name="plusCircle" size={16} />Add class</button>
      </div>
    </div>
  );
}

window.HomeScreen = HomeScreen;
window.ClassroomDetailScreen = ClassroomDetailScreen;
