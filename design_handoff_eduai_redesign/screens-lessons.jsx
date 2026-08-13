function LessonsScreen({ push }) {
  const [grade, setGrade] = React.useState('P1–P6');
  const [downloaded, setDownloaded] = React.useState(() => new Set(window.DATA.lessons.items.filter(l => l.downloaded).map(l => l.id)));
  const items = window.DATA.lessons.items.filter(l => l.grade === grade);
  function toggleDownload(e, id) {
    e.stopPropagation();
    setDownloaded(d => { const n = new Set(d); n.has(id) ? n.delete(id) : n.add(id); return n; });
  }
  return (
    <div className="col gap-12">
      <div className="grade-tabs">
        {window.DATA.lessons.grades.map(g => <button key={g} className={"grade-tab" + (g === grade ? " active" : "")} onClick={() => setGrade(g)}>{g}</button>)}
      </div>
      <div className="lesson-grid">
        {items.map(l => (
          <div key={l.id} className="card lesson-card" onClick={() => push({ title: l.title, data: l })}>
            <div className="lesson-cover" style={{ background: 'linear-gradient(135deg,var(--brand-soft),var(--surface-sunken))', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--brand)' }}><Icon name="book" size={26} /></div>
            <div className="faint" style={{ fontSize: 11.5, fontWeight: 700, textTransform: 'uppercase', marginBottom: 2 }}>{l.subject}</div>
            <div style={{ fontWeight: 700, fontSize: 14.5, marginBottom: 8, lineHeight: 1.3 }}>{l.title}</div>
            <div className="row between">
              {l.reb ? <span className="badge badge-brand">REB aligned</span> : <span />}
              <button className="icon-btn" style={downloaded.has(l.id) ? { background: 'var(--success-soft)', color: 'var(--success)' } : {}} onClick={e => toggleDownload(e, l.id)}>
                <Icon name={downloaded.has(l.id) ? "checkCircle" : "download"} size={15} />
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function LessonReaderScreen({ sub }) {
  const lesson = sub.data;
  const paras = window.DATA.lessonBody[lesson.id] || ["This lesson's content will appear here, fully available offline once downloaded."];
  const [annotate, setAnnotate] = React.useState(false);
  const [done, setDone] = React.useState(false);
  return (
    <div className="col gap-14">
      <div className="row gap-8">
        <span className="badge badge-neutral">{lesson.subject}</span>
        {lesson.reb && <span className="badge badge-brand">REB aligned</span>}
      </div>
      <div style={{ position: 'relative' }}>
        <div className="card reader-page">{paras.map((p, i) => <p key={i}>{p}</p>)}</div>
        {annotate && <div style={{ position: 'absolute', inset: 0 }}><InkCanvas height={'100%'} guide="plain" tool="highlighter" color="#F5C518" /></div>}
      </div>
      <div className="annot-toggle-bar">
        <button className={"btn " + (annotate ? "btn-primary" : "btn-soft")} onClick={() => setAnnotate(a => !a)}><Icon name="highlighter" size={16} />{annotate ? "Annotating — tap to stop" : "Annotate with pen"}</button>
      </div>
      <button className={"btn btn-block " + (done ? "btn-outline" : "btn-primary")} onClick={() => setDone(true)} disabled={done}>
        <Icon name="checkCircle" size={16} />{done ? "Marked complete — nice work" : "Mark as complete"}
      </button>
    </div>
  );
}

window.LessonsScreen = LessonsScreen;
window.LessonReaderScreen = LessonReaderScreen;
