const ROLES = {
  student: {
    tabs: [
      { id: 'home', label: 'Home', icon: 'home' },
      { id: 'tutor', label: 'Tutor', icon: 'sparkles' },
      { id: 'workbook', label: 'Workbook', icon: 'pen' },
      { id: 'lessons', label: 'Lessons', icon: 'book' },
      { id: 'progress', label: 'Progress', icon: 'chart' },
    ],
    screens: { home: window.HomeScreen, tutor: window.TutorScreen, workbook: window.WorkbookScreen, lessons: window.LessonsScreen, progress: window.ProgressScreen },
    subScreens: { home: window.ClassroomDetailScreen, lessons: window.LessonReaderScreen },
    default: 'home',
  },
  parent: {
    tabs: [
      { id: 'overview', label: 'Overview', icon: 'home' },
      { id: 'reports', label: 'Reports', icon: 'chart' },
      { id: 'messages', label: 'Messages', icon: 'mail' },
      { id: 'billing', label: 'Plan', icon: 'shield' },
    ],
    screens: { overview: window.ParentOverview, reports: window.ParentReports, messages: window.ParentMessages, billing: window.ParentBilling },
    subScreens: {},
    default: 'overview',
  },
  admin: {
    tabs: [
      { id: 'license', label: 'License', icon: 'shield' },
      { id: 'seats', label: 'Seats', icon: 'users' },
      { id: 'invoices', label: 'Invoices', icon: 'fileText' },
      { id: 'usage', label: 'Usage', icon: 'chart' },
    ],
    screens: { license: window.AdminLicense, seats: window.AdminSeats, invoices: window.AdminInvoices, usage: window.AdminUsage },
    subScreens: {},
    default: 'license',
  },
};

function lsGet(k, fallback) { try { return localStorage.getItem(k) || fallback; } catch (e) { return fallback; } }

function Segmented({ options, value, onChange, labels }) {
  return (
    <div className="segmented">
      {options.map(o => <button key={o} className={value === o ? 'active' : ''} onClick={() => onChange(o)}>{labels ? labels[o] : o}</button>)}
    </div>
  );
}

function Toast({ text }) {
  if (!text) return null;
  return <div style={{ position: 'fixed', bottom: 24, left: '50%', transform: 'translateX(-50%)', background: '#1a1b22', color: '#fff', padding: '10px 18px', borderRadius: 999, fontSize: 13.5, fontWeight: 600, zIndex: 999, boxShadow: '0 8px 24px rgba(0,0,0,.3)' }}>{text}</div>;
}

const DESKTOP_W = 1060, DESKTOP_H = 630;

function useFitScale(active) {
  const [scale, setScale] = React.useState(1);
  React.useEffect(() => {
    if (!active) { setScale(1); return; }
    const compute = () => setScale(Math.min(1, (window.innerWidth - 80) / DESKTOP_W, (window.innerHeight - 220) / DESKTOP_H));
    compute();
    window.addEventListener('resize', compute);
    return () => window.removeEventListener('resize', compute);
  }, [active]);
  return scale;
}

function App() {
  const [platform, setPlatform] = React.useState(lsGet('eduai-platform', 'ios'));
  const [theme, setTheme] = React.useState(lsGet('eduai-theme', 'light'));
  const [role, setRole] = React.useState(lsGet('eduai-role', 'student'));
  const [activeTabs, setActiveTabs] = React.useState({ student: 'home', parent: 'overview', admin: 'license' });
  const [subscreens, setSubscreens] = React.useState({ student: {}, parent: {}, admin: {} });
  const [activeChild, setActiveChild] = React.useState(0);
  const [lang, setLang] = React.useState('English');
  const [toast, setToast] = React.useState('');

  React.useEffect(() => { localStorage.setItem('eduai-platform', platform); }, [platform]);
  React.useEffect(() => { localStorage.setItem('eduai-theme', theme); }, [theme]);
  React.useEffect(() => { localStorage.setItem('eduai-role', role); }, [role]);
  React.useEffect(() => {
    const onNav = (e) => setActiveTabs(p => ({ ...p, student: e.detail }));
    window.addEventListener('nav-tab', onNav);
    return () => window.removeEventListener('nav-tab', onNav);
  }, []);
  function flash(msg) { setToast(msg); setTimeout(() => setToast(''), 1800); }

  const isDesktop = platform === 'macos' || platform === 'windows';
  const scale = useFitScale(isDesktop);
  const cfg = ROLES[role];
  const activeTab = activeTabs[role];
  const sub = subscreens[role][activeTab];
  const push = (obj) => setSubscreens(p => ({ ...p, [role]: { ...p[role], [activeTab]: obj } }));
  const pop = () => setSubscreens(p => ({ ...p, [role]: { ...p[role], [activeTab]: null } }));

  const Screen = sub ? cfg.subScreens[activeTab] : cfg.screens[activeTab];
  const tabLabel = cfg.tabs.find(t => t.id === activeTab).label;
  const title = sub ? sub.title : tabLabel;

  const menuItems = [
    { icon: 'lock', label: 'Set / change offline PIN', onClick: () => flash('Offline PIN saved') },
    { icon: 'globe', label: 'Language: ' + lang, onClick: () => setLang(l => window.DATA.languages[(window.DATA.languages.indexOf(l) + 1) % window.DATA.languages.length]) },
    { icon: 'logout', label: 'Sign out', danger: true, onClick: () => flash('Signed out (demo)') },
  ];

  return (
    <div>
      <div className="meta-bar">
        <div className="meta-group"><span className="meta-label">Platform</span><Segmented options={['ios', 'android', 'macos', 'windows']} value={platform} onChange={setPlatform} labels={{ ios: 'iOS', android: 'Android', macos: 'macOS', windows: 'Windows' }} /></div>
        <div className="meta-group"><span className="meta-label">View as</span><Segmented options={['student', 'parent', 'admin']} value={role} onChange={setRole} labels={{ student: 'Student', parent: 'Parent', admin: 'School admin' }} /></div>
        <div className="meta-group"><span className="meta-label">Appearance</span><Segmented options={['light', 'dark']} value={theme} onChange={setTheme} labels={{ light: 'Light', dark: 'Dark' }} /></div>
      </div>
      <div className="stage">
        <div className="app-root" data-platform={platform} data-theme={theme}
          style={isDesktop ? { width: DESKTOP_W * scale, height: DESKTOP_H * scale } : undefined}>
          <div style={isDesktop ? { width: DESKTOP_W, height: DESKTOP_H, transform: `scale(${scale})`, transformOrigin: 'top left' } : undefined}>
            <Shell platform={platform} theme={theme} role={role} tabs={cfg.tabs} activeTab={activeTab}
              desktopWidth={DESKTOP_W} desktopHeight={DESKTOP_H}
              onTabChange={(id) => setActiveTabs(p => ({ ...p, [role]: id }))}
              title={title} showBack={!!sub} onBack={pop} online={true} menuItems={menuItems}>
              <Screen push={push} pop={pop} sub={sub} platform={platform} theme={theme} activeChild={activeChild} setActiveChild={setActiveChild} />
            </Shell>
          </div>
        </div>
      </div>
      <Toast text={toast} />
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
