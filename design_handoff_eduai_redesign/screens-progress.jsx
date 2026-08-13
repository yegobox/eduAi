function Ring({ value, color = 'brand', size = 74 }) {
  const c = `var(--${color})`;
  return (
    <div className="ring" style={{ width: size, height: size, background: `conic-gradient(${c} ${value * 3.6}deg, var(--surface-sunken) 0)` }}>
      <div className="ring" style={{ position: 'absolute', inset: 6, background: 'var(--surface)' }} />
      <div className="ring-inner">{value}%</div>
    </div>
  );
}

function ProgressScreen() {
  const p = window.DATA.progress;
  const [shared, setShared] = React.useState(p.shared);
  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return (
    <div className="col gap-16">
      <div className="col gap-10">
        <div className="section-title">Mastery by subject</div>
        <div className="row gap-16" style={{ flexWrap: 'wrap' }}>
          {p.subjects.map(s => (
            <div key={s.name} className="card col gap-8" style={{ alignItems: 'center', flex: '1 1 140px' }}>
              <Ring value={s.mastery} color={s.color} />
              <div style={{ fontWeight: 700, fontSize: 13.5 }}>{s.name}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="card col gap-10">
        <div className="row between"><div className="section-title">7-day streak</div><Icon name="star" size={16} /></div>
        <div className="streak-row">
          {p.streak.map((d, i) => <div key={i} className={"streak-dot" + (d ? " done" : "")}>{days[i]}</div>)}
        </div>
      </div>
      <div className="card col gap-10">
        <div className="row between"><div className="section-title">REB exam readiness</div><span className="badge badge-brand">{p.examReadiness}%</span></div>
        <div className="bar-track"><div className="bar-fill" style={{ width: p.examReadiness + '%' }} /></div>
        <div className="faint" style={{ fontSize: 12.5 }}>Based on past-paper drills and lesson mastery this term.</div>
      </div>
      <div className="card row between">
        <div className="col gap-4">
          <div style={{ fontWeight: 700, fontSize: 14 }}>Share weekly report with parent</div>
          <div className="faint" style={{ fontSize: 12.5 }}>Your parent will see mastery, not every mistake.</div>
        </div>
        <label className="switch"><input type="checkbox" checked={shared} onChange={e => setShared(e.target.checked)} /><span className="track" /><span className="thumb" /></label>
      </div>
    </div>
  );
}

window.ProgressScreen = ProgressScreen;
