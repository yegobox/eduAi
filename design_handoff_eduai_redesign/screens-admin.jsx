function AdminLicense() {
  const p = window.DATA.admin.plan;
  const pct = Math.round(p.seatsUsed / p.seatsTotal * 100);
  const monthly = p.pricePerSeat * p.seatsUsed;
  return (
    <div className="col gap-16">
      <div className="card row gap-16">
        <div className="col gap-4" style={{ flex: 1 }}><div className="faint" style={{ fontSize: 12 }}>Plan</div><div style={{ fontWeight: 800, fontSize: 18 }}>{p.tier}</div></div>
        <div className="col gap-4" style={{ flex: 1 }}><div className="faint" style={{ fontSize: 12 }}>Monthly cost</div><div style={{ fontWeight: 800, fontSize: 18 }}>{monthly.toLocaleString()} RWF</div></div>
        <div className="col gap-4" style={{ flex: 1 }}><div className="faint" style={{ fontSize: 12 }}>Renews</div><div style={{ fontWeight: 800, fontSize: 18 }}>{p.renews}</div></div>
      </div>
      <div className="card col gap-8">
        <div className="row between"><div className="section-title">Seats used</div><span className="faint">{p.seatsUsed} / {p.seatsTotal}</span></div>
        <div className="bar-track"><div className="bar-fill" style={{ width: pct + '%' }} /></div>
        <div className="faint" style={{ fontSize: 12.5 }}>{p.pricePerSeat.toLocaleString()} RWF per student / month, billed monthly by Mobile Money or bank transfer.</div>
      </div>
      <div className="col gap-10">
        <div className="section-title">Plans</div>
        <div className="pricing-grid">
          {window.DATA.admin.tiers.map(t => (
            <div key={t.name} className={"pricing-card" + (t.reco ? " reco" : "")}>
              {t.reco && <span className="badge badge-brand" style={{ position: 'absolute', top: -10, left: 14 }}>Current</span>}
              <div style={{ fontWeight: 700 }}>{t.name}</div>
              <div className="price">{t.price.toLocaleString()} <span style={{ fontSize: 13, fontWeight: 600 }}>RWF/student</span></div>
              <div className="faint" style={{ fontSize: 12.5, marginBottom: 10 }}>{t.seats}</div>
              <div className="col gap-6" style={{ marginBottom: 12 }}>
                {t.features.map(f => <div key={f} className="row gap-8" style={{ fontSize: 12.5 }}><Icon name="checkCircle" size={14} />{f}</div>)}
              </div>
              <button className={"btn btn-sm btn-block " + (t.reco ? "btn-outline" : "btn-primary")}>{t.reco ? "Current plan" : "Switch plan"}</button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function AdminSeats() {
  const [classes, setClasses] = React.useState(window.DATA.admin.classes);
  const total = classes.reduce((a, c) => a + c.seats, 0);
  const adj = (i, d) => setClasses(cs => cs.map((c, j) => j === i ? { ...c, seats: Math.max(0, c.seats + d) } : c));
  return (
    <div className="col gap-16">
      <div className="row between"><div className="section-title">Seats by class</div><span className="badge badge-brand">{total} total</span></div>
      {classes.map((c, i) => (
        <div key={c.name} className="card row between">
          <div style={{ fontWeight: 700, fontSize: 14 }}>{c.name}</div>
          <div className="row gap-10">
            <button className="icon-btn" onClick={() => adj(i, -5)}><Icon name="minus" size={15} /></button>
            <span style={{ fontWeight: 700, minWidth: 30, textAlign: 'center' }}>{c.seats}</span>
            <button className="icon-btn" onClick={() => adj(i, 5)}><Icon name="plus" size={15} /></button>
          </div>
        </div>
      ))}
      <button className="btn btn-soft btn-block"><Icon name="plusCircle" size={16} />Add a class</button>
    </div>
  );
}

function AdminInvoices() {
  return (
    <div className="col gap-16">
      <div className="section-title">Invoice history</div>
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <table className="admin-table">
          <thead><tr><th>Invoice</th><th>Date</th><th>Amount</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {window.DATA.admin.invoices.map(inv => (
              <tr key={inv.id}>
                <td style={{ fontWeight: 600 }}>{inv.id}</td>
                <td className="faint">{inv.date}</td>
                <td>{inv.amount.toLocaleString()} RWF</td>
                <td><span className="badge badge-success">{inv.status}</span></td>
                <td><button className="icon-btn"><Icon name="download" size={15} /></button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="muted" style={{ fontSize: 12.5 }}>Paid via MTN Mobile Money — receipts are emailed automatically to the school bursar.</div>
    </div>
  );
}

function AdminUsage() {
  const u = window.DATA.admin.usage;
  return (
    <div className="col gap-16">
      <div className="row gap-12" style={{ flexWrap: 'wrap' }}>
        <div className="stat-tile"><div className="val">{u.activePct}%</div><div className="faint" style={{ fontSize: 12.5 }}>students active this week</div></div>
        <div className="stat-tile"><div className="val">{u.sessionsPerWeek}</div><div className="faint" style={{ fontSize: 12.5 }}>tutor sessions / student / week</div></div>
        <div className="stat-tile"><div className="val">+{u.masteryLift}%</div><div className="faint" style={{ fontSize: 12.5 }}>mastery lift this term</div></div>
      </div>
      <div className="card row gap-8" style={{ alignItems: 'center' }}>
        <Icon name="star" size={18} />
        <div style={{ fontSize: 13.5 }}>Most-practised subject this month: <b>{u.topSubject}</b></div>
      </div>
      <div className="muted" style={{ fontSize: 13 }}>Usage like this is what your renewal conversation is built on — share it with your school board each term.</div>
    </div>
  );
}

window.AdminLicense = AdminLicense;
window.AdminSeats = AdminSeats;
window.AdminInvoices = AdminInvoices;
window.AdminUsage = AdminUsage;
