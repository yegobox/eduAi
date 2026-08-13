function StatusChip({ online }) {
  return (
    <div className={"chip " + (online ? "chip-success" : "chip-warning")}>
      <Icon name={online ? "cloud" : "cloudOff"} size={14} />
      {online ? "Online" : "Offline"}
    </div>
  );
}

function MoreSheet({ platform, items, onClose }) {
  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div className="sheet" onClick={e => e.stopPropagation()}>
        {(platform === 'ios' || platform === 'android') && <div className="sheet-grabber" />}
        {items.map((it, i) => (
          <button key={i} className={"sheet-item" + (it.danger ? " danger" : "")} onClick={() => { it.onClick && it.onClick(); onClose(); }}>
            <Icon name={it.icon} size={18} />{it.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function TrailingActions({ online, onMenu }) {
  return (
    <div className="row gap-8">
      <StatusChip online={online} />
      <button className="icon-btn" onClick={onMenu}><Icon name="moreV" size={18} /></button>
    </div>
  );
}

function MobileTabBar({ kind, tabs, activeTab, onTabChange }) {
  const cls = kind === 'ios' ? 'ios-tabbar' : 'android-tabbar';
  return (
    <nav className={cls}>
      {tabs.map(t => {
        const active = t.id === activeTab;
        return (
          <button key={t.id} className={active ? 'active' : ''} onClick={() => onTabChange(t.id)}>
            {kind === 'android'
              ? <span className="pill"><Icon name={t.icon} size={20} /></span>
              : <Icon name={t.icon} size={22} />}
            {t.label}
          </button>
        );
      })}
    </nav>
  );
}

function ToolbarTabs({ kind, tabs, activeTab, onTabChange }) {
  return (
    <div className={"toolbar-tabs " + kind}>
      {tabs.map(t => (
        <button key={t.id} className={t.id === activeTab ? 'active' : ''} onClick={() => onTabChange(t.id)}>
          <Icon name={t.icon} size={kind === 'mac' ? 14 : 16} />{t.label}
        </button>
      ))}
    </div>
  );
}

function WinTitleBar({ theme }) {
  return (
    <div className="win-titlebar">
      <div style={{ width: 18, height: 18, borderRadius: 4, background: 'var(--brand)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name="sparkles" size={11} />
      </div>
      <span className="app-name">EduAI</span>
      <div className="win-caption-btns">
        <button className="win-cap"><Icon name="winMin" size={12} /></button>
        <button className="win-cap"><Icon name="winMax" size={11} /></button>
        <button className="win-cap close"><Icon name="winClose" size={12} /></button>
      </div>
    </div>
  );
}

function WinTabStrip({ tabs, activeTab, onTabChange, showBack, onBack, title, online, onMenu }) {
  return (
    <div className="win-tabstrip">
      {showBack ? (
        <div className="row gap-10" style={{ flex: 1 }}>
          <button className="desk-back" onClick={onBack}><Icon name="chevronLeft" size={16} /></button>
          <div className="nav-title" style={{ fontSize: 15 }}>{title}</div>
        </div>
      ) : (
        <ToolbarTabs kind="win" tabs={tabs} activeTab={activeTab} onTabChange={onTabChange} />
      )}
      <div style={{ flex: 1 }} />
      <TrailingActions online={online} onMenu={onMenu} />
    </div>
  );
}

// Shell — adapts nav chrome + device bezel per platform. Screen content is passed as children
// and is platform-agnostic; CSS vars (set via data-platform/data-theme upstream) handle visual adaptation.
function Shell({ platform, theme, role, tabs, activeTab, onTabChange, title, showBack, onBack, online, menuItems, children, desktopWidth = 1080, desktopHeight = 680 }) {
  const [menuOpen, setMenuOpen] = React.useState(false);
  const menu = menuOpen && <MoreSheet platform={platform} items={menuItems} onClose={() => setMenuOpen(false)} />;

  if (platform === 'ios') {
    return (
      <IOSDevice dark={theme === 'dark'}>
        <div className="ios-shell">
          <div className={"ios-navbar" + (showBack ? " compact" : "")}>
            {showBack && <button className="ios-back" onClick={onBack}><Icon name="chevronLeft" size={18} /></button>}
            <div className="nav-title">{title}</div>
            {!showBack && <TrailingActions online={online} onMenu={() => setMenuOpen(true)} />}
          </div>
          <div className="ios-content">{children}</div>
          {!showBack && <MobileTabBar kind="ios" tabs={tabs} activeTab={activeTab} onTabChange={onTabChange} />}
          {menu}
        </div>
      </IOSDevice>
    );
  }
  if (platform === 'android') {
    return (
      <AndroidDevice dark={theme === 'dark'}>
        <div className="android-shell">
          <div className="android-appbar">
            {showBack ? <button className="icon-btn" onClick={onBack}><Icon name="chevronLeft" size={18} /></button> : <div style={{ width: 8 }} />}
            <div className="nav-title">{title}</div>
            {!showBack && <TrailingActions online={online} onMenu={() => setMenuOpen(true)} />}
          </div>
          <div className="android-content">{children}</div>
          {!showBack && <MobileTabBar kind="android" tabs={tabs} activeTab={activeTab} onTabChange={onTabChange} />}
          {menu}
        </div>
      </AndroidDevice>
    );
  }
  if (platform === 'macos') {
    return (
      <MacWindow width={desktopWidth} height={desktopHeight} title={title} dark={theme === 'dark'}
        onBack={showBack ? onBack : null}
        center={!showBack && <ToolbarTabs kind="mac" tabs={tabs} activeTab={activeTab} onTabChange={onTabChange} />}
        toolbarActions={<TrailingActions online={online} onMenu={() => setMenuOpen(true)} />}>
        <div className="desk-content" style={{ position: 'relative' }}>{children}{menu}</div>
      </MacWindow>
    );
  }
  // windows
  return (
    <div className="win-frame" style={{ width: desktopWidth, height: desktopHeight }}>
      <WinTitleBar theme={theme} />
      <WinTabStrip tabs={tabs} activeTab={activeTab} onTabChange={onTabChange} showBack={showBack} onBack={onBack} title={title} online={online} onMenu={() => setMenuOpen(true)} />
      <div className="win-main">
        <div className="desk-content" style={{ position: 'relative', flex: 1, overflow: 'auto' }}>{children}{menu}</div>
      </div>
    </div>
  );
}

window.Shell = Shell;
window.StatusChip = StatusChip;
