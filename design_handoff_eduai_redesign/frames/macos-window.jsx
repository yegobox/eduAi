// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)
// Copied omelette starter. Re-running copy_starter_component with this kind overwrites this file with the latest version (page content is unaffected).

/* BEGIN USAGE */
// MacOS.jsx — Simplified macOS Tahoe (Liquid Glass) window
// Based on the macOS Tahoe UI Kit. No image assets, no dependencies.
// Exports (to window): MacWindow, MacSidebar, MacSidebarItem, MacSidebarHeader, MacToolbar, MacGlass, MacTrafficLights
//
// Usage — wrap your app content in <MacWindow> to get the window chrome
// (traffic lights + titlebar). Props: width, height, title, sidebar (pass a
// <MacSidebar> element); compose MacToolbar/MacGlass inside as needed:
//
//   <MacWindow width={980} height={620} title="Documents"
//              sidebar={<MacSidebar>…</MacSidebar>}>
//     ...your app content...
//   </MacWindow>
/* END USAGE */

const MAC_FONT = '-apple-system, BlinkMacSystemFont, "SF Pro", "Helvetica Neue", sans-serif';

// ─────────────────────────────────────────────────────────────
// Liquid glass primitive — blur + white tint + inset highlight
// ─────────────────────────────────────────────────────────────
function MacGlass({ children, radius = 296, dark = false, style = {} }) {
  return (
    <div style={{ position: 'relative', borderRadius: radius, ...style }}>
      <div style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.35)',
        backdropFilter: 'blur(40px) saturate(180%)',
        WebkitBackdropFilter: 'blur(40px) saturate(180%)',
        border: dark ? '0.5px solid rgba(255,255,255,0.12)' : '0.5px solid rgba(255,255,255,0.6)',
        boxShadow: dark
          ? '0 8px 40px rgba(0,0,0,0.2)'
          : '0 8px 40px rgba(0,0,0,0.08), inset 0 1px 0 rgba(255,255,255,0.4)',
      }} />
      <div style={{ position: 'relative', zIndex: 1 }}>{children}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Traffic lights (14px, Tahoe colors)
// ─────────────────────────────────────────────────────────────
function MacTrafficLights({ style = {} }) {
  const dot = (bg) => (
    <div style={{
      width: 14, height: 14, borderRadius: '50%', background: bg,
      border: '0.5px solid rgba(0,0,0,0.1)',
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 9, alignItems: 'center', padding: 1, ...style }}>
      {dot('#ff736a')}{dot('#febc2e')}{dot('#19c332')}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Toolbar — title + single glass pill icon
// ─────────────────────────────────────────────────────────────
function MacToolbar({ title = 'Folder', onBack, actions, dark = false, center }) {
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '1fr auto 1fr', alignItems: 'center', gap: 8,
      padding: '10px 14px', flexShrink: 0,
      borderBottom: dark ? '1px solid rgba(255,255,255,0.08)' : '1px solid rgba(0,0,0,0.07)',
      background: dark ? 'rgba(255,255,255,0.02)' : 'rgba(0,0,0,0.012)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
        <MacTrafficLights />
        {onBack && (
          <MacGlass>
            <button onClick={onBack} style={{
              width: 30, height: 30, display: 'flex', border: 'none', background: 'none', cursor: 'pointer',
              alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="9" height="15" viewBox="0 0 9 15"><path d="M7.5 1.5l-6 6 6 6" stroke="#4c4c4c" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </button>
          </MacGlass>
        )}
        <div style={{
          fontFamily: MAC_FONT, fontSize: 13, fontWeight: 700,
          color: dark ? 'rgba(255,255,255,0.85)' : 'rgba(0,0,0,0.7)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>{title}</div>
      </div>
      <div>{center}</div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>{actions}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Sidebar — frosted glass panel floating inside the window
// ─────────────────────────────────────────────────────────────
function MacSidebarItem({ label, selected = false }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 6,
      height: 24, padding: '4px 10px 4px 6px', margin: '0 10px',
      borderRadius: 8, position: 'relative',
      fontFamily: MAC_FONT, fontSize: 11, fontWeight: 500,
    }}>
      {selected && (
        <div style={{
          position: 'absolute', inset: 0, borderRadius: 8,
          background: 'rgba(0,0,0,0.11)', mixBlendMode: 'multiply',
        }} />
      )}
      <div style={{
        width: 14, height: 14, borderRadius: '50%',
        background: selected ? '#007aff' : 'rgba(0,0,0,0.4)',
        opacity: selected ? 1 : 0.5, flexShrink: 0, position: 'relative',
      }} />
      <span style={{ color: 'rgba(0,0,0,0.85)', position: 'relative' }}>{label}</span>
    </div>
  );
}

function MacSidebar({ children, dark = false }) {
  return (
    <div style={{
      width: 220, height: '100%', padding: 8, flexShrink: 0,
      position: 'relative', display: 'flex', flexDirection: 'column',
    }}>
      {/* glass panel */}
      <div style={{
        position: 'absolute', inset: 8, borderRadius: 18,
        background: dark ? 'rgba(45,48,66,0.7)' : 'rgba(200,208,250,0.55)',
        backdropFilter: 'blur(50px) saturate(200%)',
        WebkitBackdropFilter: 'blur(50px) saturate(200%)',
        border: dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(255,255,255,0.6)',
        boxShadow: '0 8px 40px rgba(0,0,0,0.10), inset 0 1px 0 rgba(255,255,255,0.35)',
      }} />
      {/* content */}
      <div style={{
        position: 'relative', zIndex: 1, padding: '10px 0',
        display: 'flex', flexDirection: 'column', gap: 2,
      }}>
        {/* window controls + sidebar toggle */}
        <div style={{
          height: 32, display: 'flex', alignItems: 'center',
          justifyContent: 'space-between', padding: '0 10px', marginBottom: 4,
        }}>
          <MacTrafficLights />
        </div>
        {children}
      </div>
    </div>
  );
}

function MacSidebarHeader({ title }) {
  return (
    <div style={{
      padding: '14px 18px 5px',
      fontFamily: MAC_FONT, fontSize: 11, fontWeight: 700,
      color: 'rgba(0,0,0,0.5)',
    }}>{title}</div>
  );
}

// ─────────────────────────────────────────────────────────────
// Window — r:26, big shadow, sidebar + toolbar + content
// ─────────────────────────────────────────────────────────────
function MacWindow({
  width = 900, height = 600, title = 'Folder',
  sidebar, children, onBack, toolbarActions, center, dark = false,
}) {
  return (
    // data-om-starter: inert presence marker — Claude Design's starter-usage
    // probe reads it; it renders nothing. Keep it on this root element.
    <div data-om-starter="macos-window" style={{
      width, height, borderRadius: 26, overflow: 'hidden',
      background: dark ? '#1e1e22' : '#fff',
      boxShadow: '0 0 0 1px rgba(0,0,0,0.23), 0 16px 48px rgba(0,0,0,0.35)',
      display: 'flex', position: 'relative',
      fontFamily: MAC_FONT,
    }}>
      {sidebar && <MacSidebar dark={dark}>{sidebar}</MacSidebar>}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <MacToolbar title={title} onBack={onBack} actions={toolbarActions} dark={dark} center={center} />
        <div style={{ flex: 1, overflow: 'auto', padding: '4px 8px' }}>
          {children}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  MacWindow, MacSidebar, MacSidebarItem, MacSidebarHeader,
  MacToolbar, MacGlass, MacTrafficLights,
});
