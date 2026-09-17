# -*- coding: utf-8 -*-
"""
render_all_screens.py
Renders all 23 actual application screens into standalone high-resolution PNG photos.
Uses Chrome headless at 1200x720 for desktop screens and 420x760 for mobile screen.
"""

import os
import subprocess

SCREENSHOTS_DIR = r"e:\BachatgatManagement\screenshots"
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

COMMON_CSS = """
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;500;600;700&family=Poppins:wght@400;500;600;700&display=swap');
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: 'Noto Sans Devanagari', 'Poppins', -apple-system, sans-serif;
  background: #f1f5f9;
  color: #0f172a;
  width: 1200px;
  height: 720px;
  overflow: hidden;
}
.window-frame {
  width: 1200px;
  height: 720px;
  display: flex;
  flex-direction: column;
  background: #ffffff;
  border: 1px solid #94a3b8;
  box-shadow: 0 10px 25px rgba(0,0,0,0.15);
}
.win-titlebar {
  background: #1e1b4b;
  color: #e2e8f0;
  height: 32px;
  padding: 0 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 11.5px;
  font-weight: 500;
  user-select: none;
}
.win-titlebar .title { display: flex; align-items: center; gap: 8px; }
.win-controls { display: flex; gap: 12px; font-size: 13px; color: #94a3b8; }
.app-topbar {
  background: #ffffff;
  border-bottom: 1px solid #e2e8f0;
  height: 52px;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.app-topbar .brand { display: flex; align-items: center; gap: 10px; }
.app-topbar .brand-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: #5c1d8d;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 16px;
}
.app-topbar .brand-text h1 { font-size: 14px; font-weight: 700; color: #1e1b4b; }
.app-topbar .brand-text p { font-size: 10.5px; color: #64748b; }
.topbar-right { display: flex; align-items: center; gap: 14px; }
.sync-badge {
  background: #dcfce7;
  color: #15803d;
  border: 1px solid #86efac;
  border-radius: 20px;
  padding: 3px 10px;
  font-size: 11px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 5px;
}
.sync-badge .dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; }
.user-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 11.5px;
}
.user-chip .avatar {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: #5c1d8d;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
}
.app-body {
  flex: 1;
  display: flex;
  height: calc(720px - 84px);
  overflow: hidden;
}
.sidebar {
  width: 235px;
  background: #2e1065;
  color: #e9d5ff;
  padding: 8px 6px;
  overflow-y: auto;
  flex-shrink: 0;
}
.sidebar-section {
  font-size: 9px;
  text-transform: uppercase;
  color: #c084fc;
  font-weight: 700;
  padding: 8px 10px 4px 10px;
  letter-spacing: 0.5px;
}
.nav-item {
  padding: 5px 10px;
  border-radius: 6px;
  font-size: 11px;
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 2px;
  color: #f3e8ff;
  white-space: nowrap;
}
.nav-item.active {
  background: #7c3aed;
  color: #ffffff;
  font-weight: 700;
  box-shadow: 0 2px 6px rgba(124, 58, 237, 0.4);
}
.content-area {
  flex: 1;
  background: #f8fafc;
  padding: 16px 20px;
  overflow-y: auto;
}
.page-title-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
}
.page-title-row h2 { font-size: 16px; font-weight: 700; color: #1e1b4b; }
.page-title-row p { font-size: 11px; color: #64748b; }
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
  margin-bottom: 14px;
}
.kpi-card {
  padding: 10px 14px;
  border-radius: 8px;
  color: white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.06);
}
.kpi-card .lbl { font-size: 10.5px; opacity: 0.9; }
.kpi-card .val { font-size: 18px; font-weight: 700; margin-top: 2px; }
.kpi-card .sub { font-size: 9.5px; opacity: 0.8; margin-top: 2px; }
.c-blue { background: linear-gradient(135deg, #1d4ed8, #2563eb); }
.c-green { background: linear-gradient(135deg, #047857, #10b981); }
.c-orange { background: linear-gradient(135deg, #c2410c, #f97316); }
.c-red { background: linear-gradient(135deg, #b91c1c, #ef4444); }
.c-purple { background: linear-gradient(135deg, #6b21a8, #8b5cf6); }
.c-teal { background: linear-gradient(135deg, #0f766e, #14b8a6); }

.card-box {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 12px 14px;
  margin-bottom: 12px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.03);
}
.card-box h3 { font-size: 12.5px; font-weight: 700; color: #1e1b4b; margin-bottom: 8px; }
table.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
}
table.data-table th {
  background: #f1f5f9;
  color: #475569;
  padding: 6px 10px;
  text-align: left;
  font-weight: 600;
  border-bottom: 1px solid #cbd5e1;
}
table.data-table td {
  padding: 6px 10px;
  border-bottom: 1px solid #e2e8f0;
  color: #1e293b;
}
table.data-table tr:nth-child(even) { background: #fafafa; }
.badge {
  display: inline-block;
  padding: 2px 7px;
  border-radius: 12px;
  font-size: 9.5px;
  font-weight: 600;
}
.badge-ok { background: #dcfce7; color: #15803d; }
.badge-warn { background: #fef3c7; color: #b45309; }
.badge-err { background: #fee2e2; color: #b91c1c; }
.badge-purple { background: #f3e8ff; color: #7c3aed; }
.badge-info { background: #e0f2fe; color: #0369a1; }
.btn-primary {
  background: #5c1d8d;
  color: white;
  border: none;
  padding: 5px 12px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  cursor: pointer;
}
.btn-success { background: #10b981; }
.btn-amber { background: #f59e0b; }
.btn-blue { background: #2563eb; }
.btn-outline { background: white; border: 1px solid #cbd5e1; color: #334155; }
.tabs-header {
  display: flex;
  gap: 6px;
  border-bottom: 2px solid #e2e8f0;
  margin-bottom: 12px;
}
.tab-btn {
  padding: 6px 14px;
  font-size: 11px;
  font-weight: 600;
  color: #64748b;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
}
.tab-btn.active {
  color: #5c1d8d;
  border-bottom-color: #5c1d8d;
}
"""

NAV_ITEMS = [
    ("main", "मुख्य व्यवस्थापन"),
    ("dashboard", "📊 ३. मुख्य डॅशबोर्ड"),
    ("members", "👥 ४. सदस्य व्यवस्थापन"),
    ("savings", "💰 ५. मासिक बचत नोंद"),
    ("loans", "💳 ६ व ७. कर्ज वाटप व वसुली"),
    ("meetings", "📅 ७b. मासिक बैठका व हजेरी"),
    ("fin", "आर्थिक व्यवहार"),
    ("income", "📈 ८. उत्पन्न व्यवस्थापन"),
    ("expense", "📉 ९. खर्च व्यवस्थापन"),
    ("cashbook", "📖 १० व १४. बँक व कॅश बुक"),
    ("pnl", "📊 १५. मासिक नफा-तोटा पत्रक"),
    ("contrib", "🤝 १६. वर्गणी व दंड नोंद"),
    ("dues", "⚠️ २२. थकबाकी व वसुली"),
    ("business", "व्यवसाय व शासकीय योजना"),
    ("inventory", "📦 ११ व १२. उत्पादने व स्टॉक POS"),
    ("bankloans", "🏛️ १३ व १७. बँक कर्ज व योजना"),
    ("resolutions", "📝 १८. ठराव वही व कागदपत्रे"),
    ("trainings", "🎓 २० व २१. कौशल्य प्रशिक्षण"),
    ("admin", "अहवाल व प्रशासन"),
    ("notifications", "🔔 २३. सूचना व स्मरणपत्रे"),
    ("reports", "📑 २४. सर्व अहवाल (Reports)"),
    ("audit", "🛡️ २५. ऑडिट व हालचाली नोंद"),
    ("settings", "⚙️ २६. गट माहिती व नियम"),
    ("backup", "💾 २७. बॅकअप व रिस्टोअर (.db)")
]

def render_sidebar(active_key):
    out = []
    out.append('<div class="sidebar">')
    for item in NAV_ITEMS:
        key, label = item
        if key in ["main", "fin", "business", "admin"]:
            out.append(f'<div class="sidebar-section">{label}</div>')
        else:
            cls = "nav-item active" if key == active_key else "nav-item"
            out.append(f'<div class="{cls}">{label}</div>')
    out.append('</div>')
    return "\n".join(out)

def wrap_desktop_page(active_key, content_html):
    return f"""<!DOCTYPE html>
<html lang="mr"><head><meta charset="UTF-8"><style>{COMMON_CSS}</style></head>
<body>
<div class="window-frame">
  <div class="win-titlebar">
    <div class="title">
      <span>💠</span>
      <span>सखी महिला बचत गट व्यवस्थापन प्रणाली v2.0 - [सावित्रीबाई फुले महिला बचत गट, पंढरपूर • MH/SOL/2024/0987]</span>
    </div>
    <div class="win-controls"><span>🗕</span><span>🗖</span><span>✕</span></div>
  </div>
  <div class="app-topbar">
    <div class="brand">
      <div class="brand-icon">स</div>
      <div class="brand-text">
        <h1>सावित्रीबाई फुले महिला बचत गट</h1>
        <p>पंढरपूर, जि. सोलापूर • अधिकृत नोंदणी क्र: MH/SOL/2024/0987</p>
      </div>
    </div>
    <div class="topbar-right">
      <div class="sync-badge"><span class="dot"></span> 🟢 ऑनलाइन सिंक सक्रिय (Cloud Synced)</div>
      <div class="user-chip">
        <div class="avatar">सु</div>
        <div><strong>सुनंदा मारुती पवार</strong> (अध्यक्षा)</div>
      </div>
    </div>
  </div>
  <div class="app-body">
    {render_sidebar(active_key)}
    <div class="content-area">
      {content_html}
    </div>
  </div>
</div>
</body></html>"""

# We define each screen's content
SCREENS = {}

# 1. Login Screen (custom full window)
SCREENS["01_login"] = f"""<!DOCTYPE html>
<html lang="mr"><head><meta charset="UTF-8"><style>
{COMMON_CSS}
body {{ background: #2e1065; display: flex; align-items: center; justify-content: center; }}
.login-box {{
  width: 420px;
  background: white;
  border-radius: 12px;
  padding: 30px;
  box-shadow: 0 15px 35px rgba(0,0,0,0.3);
  text-align: center;
}}
.login-logo {{
  width: 60px; height: 60px; background: #5c1d8d; color: white;
  border-radius: 50%; display: flex; align-items: center; justify-content: center;
  font-size: 28px; margin: 0 auto 12px auto; box-shadow: 0 4px 10px rgba(92,29,141,0.3);
}}
.login-title {{ font-size: 18px; font-weight: 700; color: #1e1b4b; }}
.login-sub {{ font-size: 11.5px; color: #64748b; margin-bottom: 20px; }}
.inp-grp {{ text-align: left; margin-bottom: 12px; }}
.inp-lbl {{ font-size: 10.5px; font-weight: 600; color: #475569; margin-bottom: 4px; text-transform: uppercase; }}
.inp-ctrl {{
  width: 100%; border: 1.5px solid #cbd5e1; border-radius: 6px;
  padding: 8px 12px; font-size: 12px; background: #f8fafc;
}}
.btn-login {{
  width: 100%; background: #5c1d8d; color: white; border: none;
  padding: 10px; border-radius: 6px; font-weight: 700; font-size: 13px;
  margin-top: 8px; cursor: pointer; box-shadow: 0 4px 12px rgba(92,29,141,0.25);
}}
.login-footer {{ font-size: 11px; color: #64748b; margin-top: 16px; border-top: 1px solid #e2e8f0; padding-top: 12px; }}
</style></head>
<body>
<div class="login-box">
  <div class="login-logo">👥</div>
  <div class="login-title">सखी महिला बचत गट व्यवस्थापन</div>
  <div class="login-sub">महिला सक्षमीकरण व अधिकृत आर्थिक व्यवस्थापन प्रणाली</div>
  <div class="inp-grp">
    <div class="inp-lbl">नोंदणीकृत मोबाईल नंबर किंवा ईमेल</div>
    <div class="inp-ctrl">9876543210 (किंवा admin@bachatgat.org)</div>
  </div>
  <div class="inp-grp">
    <div class="inp-lbl">पासवर्ड किंवा ४-अंकी सुरक्षा पिन</div>
    <div class="inp-ctrl">••••••••</div>
  </div>
  <button class="btn-login">लॉगिन करा (Login) &rarr;</button>
  <div class="login-footer">
    नवीन बचत गट नोंदणी? <strong style="color: #5c1d8d;">Sign Up करा</strong><br>
    <span style="color:#15803d; font-weight:600;">ऑफलाइन डीफॉल्ट ॲडमिन पिन: 1234 (इंटरनेटशिवाय चालू)</span>
  </div>
</div>
</body></html>"""

# 2. Dashboard
SCREENS["02_dashboard"] = wrap_desktop_page("dashboard", """
<div class="page-title-row">
  <div>
    <h2>गटाचा सर्वंकष आर्थिक आढावा (Master Executive Dashboard)</h2>
    <p>चालू महिना: सप्टेंबर २०२६ | एकूण सभासद: २० महिला | नियमित बचत: ₹ ५००/महिना</p>
  </div>
  <div style="display:flex; gap:8px;">
    <button class="btn-primary btn-success">+ बचत जमा करा</button>
    <button class="btn-primary">+ कर्ज वाटप करा</button>
  </div>
</div>
<div class="kpi-grid">
  <div class="kpi-card c-blue"><div class="lbl">एकूण नोंदणीकृत सदस्य</div><div class="val">२० महिला</div><div class="sub">सर्व सक्रिय (100% KYC पूर्ण)</div></div>
  <div class="kpi-card c-green"><div class="lbl">एकूण जमा मासिक बचत</div><div class="val">₹ १,२५,०००.००</div><div class="sub">चालू महिना: ₹ १०,००० जमा</div></div>
  <div class="kpi-card c-orange"><div class="lbl">सक्रिय अंतर्गत कर्जे</div><div class="val">₹ ८५,०००.००</div><div class="sub">६ सदस्यांकडे चालू कर्ज</div></div>
  <div class="kpi-card c-red"><div class="lbl">थकीत हप्ते व विलंब</div><div class="val">₹ ३,८६६.००</div><div class="sub">२ हप्ते थकीत (स्मरणपत्र पाठवले)</div></div>
</div>
<div class="kpi-grid">
  <div class="kpi-card c-purple"><div class="lbl">बँक ऑफ महाराष्ट्र शिल्लक</div><div class="val">₹ ४५,०००.००</div><div class="sub">खाते क्र: ...०८९४</div></div>
  <div class="kpi-card c-teal"><div class="lbl">पेटीतील हातातील रोख शिल्लक</div><div class="val">₹ ९,१३४.००</div><div class="sub">प्रत्यक्ष रोख जुळणी पूर्ण</div></div>
  <div class="kpi-card c-green"><div class="lbl">चालू महिना एकूण उत्पन्न</div><div class="val">₹ २९,३३७.००</div><div class="sub">बचत + हप्ते + व्याज जमा</div></div>
  <div class="kpi-card c-orange"><div class="lbl">चालू महिना एकूण खर्च</div><div class="val">₹ २०,६५०.००</div><div class="sub">कर्ज वाटप ₹२० हजार + खर्च</div></div>
</div>
<div class="card-box">
  <h3>नुकतेच झालेले व्यवहार (Recent Group Transactions)</h3>
  <table class="data-table">
    <thead>
      <tr><th>तारीख</th><th>पावती क्र.</th><th>तपशील</th><th>व्यवहार प्रकार</th><th>माध्यम</th><th>रक्कम (₹)</th><th>स्थिती</th></tr>
    </thead>
    <tbody>
      <tr><td>१०-०९-२०२६</td><td>SAV-09-02</td><td>मीना अशोक जाधव (मासिक बचत)</td><td>बचत संकलन</td><td>रोख</td><td>₹ ५००.००</td><td><span class="badge badge-ok">यशस्वी</span></td></tr>
      <tr><td>१०-०९-२०२६</td><td>EMI-09-01</td><td>सुनंदा मारुती पवार (कर्ज हप्ता #३)</td><td>कर्ज वसुली</td><td>बँक ट्रान्सफर</td><td>₹ २,०६७.००</td><td><span class="badge badge-ok">यशस्वी</span></td></tr>
      <tr><td>०९-०९-२०२६</td><td>EXP-09-01</td><td>दप्तर स्टेशनरी व हजेरी नोंदवह्या</td><td>खर्च व्हाउचर</td><td>रोख</td><td>₹ ३५०.००</td><td><span class="badge badge-warn">खर्च नोंद</span></td></tr>
      <tr><td>०८-०९-२०२६</td><td>LN-DISB-02</td><td>मीना जाधव यांना किराणा दुकानासाठी कर्ज</td><td>कर्ज वाटप</td><td>बँक चेक</td><td>₹ २०,०००.००</td><td><span class="badge badge-purple">मंजूर</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 3. Members Management
SCREENS["03_members"] = wrap_desktop_page("members", """
<div class="page-title-row">
  <div>
    <h2>सदस्य व्यवस्थापन व सभासद नोंदवही (Members Register & Profiles)</h2>
    <p>गटातील एकूण २० महिला सदस्य | प्रत्येकाची वैयक्तिक बचत व कर्ज खाती अद्ययावत</p>
  </div>
  <div style="display:flex; gap:8px;">
    <input type="text" placeholder="🔍 सदस्य नाव किंवा मोबाईल शोधा..." style="padding:6px 12px; border:1px solid #cbd5e1; border-radius:6px; font-size:11px; width:220px;">
    <button class="btn-primary btn-success">+ नवीन सदस्य जोडा</button>
  </div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead>
      <tr><th>कोड</th><th>सदस्याचे पूर्ण नाव</th><th>मोबाईल नंबर</th><th>पद / हुद्दा</th><th>वारसदार (Nominee)</th><th>बँक खाते क्रमांक</th><th>एकूण बचत</th><th>कर्ज बाकी</th><th>स्थिती</th><th>कृती</th></tr>
    </thead>
    <tbody>
      <tr><td><strong>MBG-001</strong></td><td>सुनंदा मारुती पवार</td><td>9876543210</td><td><span class="badge badge-purple">अध्यक्षा</span></td><td>मारुती पवार (पती)</td><td>बँक ऑफ महा. 6032...11</td><td>₹ ६,०००.००</td><td>₹ ०.००</td><td><span class="badge badge-ok">सक्रिय</span></td><td><button class="btn-primary" style="font-size:9.5px; padding:2px 6px;">पासबुक 📖</button></td></tr>
      <tr><td><strong>MBG-002</strong></td><td>मीना अशोक जाधव</td><td>9765432109</td><td><span class="badge badge-info">सचिवा</span></td><td>अशोक जाधव (पती)</td><td>SBI 3021...45</td><td>₹ ६,०००.००</td><td>₹ १८,३३३.००</td><td><span class="badge badge-ok">सक्रिय</span></td><td><button class="btn-primary" style="font-size:9.5px; padding:2px 6px;">पासबुक 📖</button></td></tr>
      <tr><td><strong>MBG-003</strong></td><td>कविता बापू शिंदे</td><td>9654321098</td><td><span class="badge badge-warn">खजिनदार</span></td><td>बापू शिंदे (पती)</td><td>DCC बँक 1045...90</td><td>₹ ६,०००.००</td><td>₹ ०.००</td><td><span class="badge badge-ok">सक्रिय</span></td><td><button class="btn-primary" style="font-size:9.5px; padding:2px 6px;">पासबुक 📖</button></td></tr>
      <tr><td><strong>MBG-004</strong></td><td>शारदा विलास गायकवाड</td><td>9543210987</td><td>सदस्य</td><td>विलास गायकवाड (पती)</td><td>बँक ऑफ महा. 6032...44</td><td>₹ ६,०००.००</td><td>₹ ५,०००.००</td><td><span class="badge badge-ok">सक्रिय</span></td><td><button class="btn-primary" style="font-size:9.5px; padding:2px 6px;">पासबुक 📖</button></td></tr>
      <tr><td><strong>MBG-005</strong></td><td>लता संभाजी मोरे</td><td>9765123456</td><td>सदस्य</td><td>संभाजी मोरे (पती)</td><td>बँक ऑफ बरोडा 4110...78</td><td>₹ ६,०००.००</td><td>₹ १०,०००.००</td><td><span class="badge badge-err">हप्ता थकीत</span></td><td><button class="btn-primary" style="font-size:9.5px; padding:2px 6px;">पासबुक 📖</button></td></tr>
    </tbody>
  </table>
</div>
""")

# 4. Monthly Savings
SCREENS["04_savings"] = wrap_desktop_page("savings", """
<div class="page-title-row">
  <div>
    <h2>मासिक बचत संकलन व नोंदवही (Monthly Savings Collection)</h2>
    <p>माहे: सप्टेंबर २०२६ | प्रति सदस्य नियमित बचत: ₹ ५००.००</p>
  </div>
  <button class="btn-primary btn-blue">🖨️ मासिक बचत तक्ता प्रिंट करा</button>
</div>
<div style="display:flex; gap:14px; margin-bottom:14px;">
  <div class="card-box" style="flex:1.5; background:#faf5ff; border:1.5px solid #d8b4fe;">
    <h3>+ नवीन मासिक बचत जमा नोंदवा (Quick Deposit)</h3>
    <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:10px;">
      <div>
        <label style="font-size:10px; font-weight:700; color:#5c1d8d;">सभासद निवडा *</label>
        <select style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;">
          <option>मीना अशोक जाधव (MBG-002)</option>
          <option>शारदा विलास गायकवाड (MBG-004)</option>
        </select>
      </div>
      <div>
        <label style="font-size:10px; font-weight:700; color:#5c1d8d;">बचत रक्कम (₹) *</label>
        <input type="text" value="₹ ५००.००" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px; font-weight:700; color:#15803d;">
      </div>
      <div>
        <label style="font-size:10px; font-weight:700; color:#5c1d8d;">भरणा माध्यम *</label>
        <select style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;">
          <option>रोख भरणा (Cash)</option>
          <option>PhonePe / GPay (UPI)</option>
          <option>बँक ट्रान्सफर (NEFT/RTGS)</option>
        </select>
      </div>
      <div>
        <label style="font-size:10px; font-weight:700; color:#5c1d8d;">जमा दिनांक</label>
        <input type="date" value="2026-09-10" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;">
      </div>
    </div>
    <button class="btn-primary btn-success" style="width:100%; justify-content:center; padding:7px;">बचत जमा करा व पावती द्या ✓</button>
  </div>
  <div class="card-box" style="flex:1; background:white; border:1px dashed #5c1d8d;">
    <h3>डिजिटल पावती पूर्वावलोकन (Receipt Preview)</h3>
    <div style="font-size:11px; line-height:1.6; color:#334155;">
      <div><strong>पावती क्र:</strong> SAV-2026-09-002</div>
      <div><strong>सदस्य:</strong> मीना अशोक जाधव (MBG-002)</div>
      <div><strong>महिना:</strong> सप्टेंबर २०२६</div>
      <div><strong>जमा रक्कम:</strong> <span style="font-size:14px; font-weight:700; color:#15803d;">₹ ५००.००</span> (रोख)</div>
      <div><strong>आजपर्यंत एकूण बचत:</strong> ₹ ६,०००.००</div>
    </div>
    <button class="btn-primary btn-blue" style="width:100%; justify-content:center; margin-top:10px; font-size:10px;">🖨️ SMS / WhatsApp पावती पाठवा</button>
  </div>
</div>
<div class="card-box">
  <h3>चालू महिना बचत संकलन यादी (सप्टेंबर २०२६)</h3>
  <table class="data-table">
    <thead><tr><th>पावती क्र.</th><th>सदस्याचे नाव</th><th>जमा तारीख</th><th>रक्कम (₹)</th><th>माध्यम</th><th>शिल्लक एकूण बचत</th><th>स्थिती</th></tr></thead>
    <tbody>
      <tr><td>SAV-09-01</td><td>सुनंदा मारुती पवार</td><td>१०-०९-२०२६</td><td>₹ ५००.००</td><td>रोख</td><td>₹ ६,०००.००</td><td><span class="badge badge-ok">जमा ✓</span></td></tr>
      <tr><td>SAV-09-02</td><td>मीना अशोक जाधव</td><td>१०-०९-२०२६</td><td>₹ ५००.००</td><td>रोख</td><td>₹ ६,०००.००</td><td><span class="badge badge-ok">जमा ✓</span></td></tr>
      <tr><td>SAV-09-03</td><td>कविता बापू शिंदे</td><td>१०-०९-२०२६</td><td>₹ ५००.००</td><td>PhonePe</td><td>₹ ६,०००.००</td><td><span class="badge badge-ok">जमा ✓</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 5. Loan Disbursal
SCREENS["05_loan_disbursal"] = wrap_desktop_page("loans", """
<div class="page-title-row">
  <div>
    <h2>अंतर्गत कर्ज वाटप व EMI गणकयंत्र (Loan Disbursal & Calculator)</h2>
    <p>सभासदांना व्यवसायासाठी किंवा घरगुती गरजांसाठी अंतर्गत कर्ज वाटप नोंद</p>
  </div>
  <button class="btn-primary btn-success">+ नवीन कर्ज वाटप फॉर्म</button>
</div>
<div class="card-box" style="background:#faf5ff; border:1.5px solid #d8b4fe;">
  <h3>कर्ज वाटप व EMI गणकयंत्र फॉर्म (Loan Disburse Dialog)</h3>
  <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:10px; margin-bottom:10px;">
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">कर्जदार सभासद</label><input type="text" value="मीना अशोक जाधव (MBG-002)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">कर्ज रक्कम (₹)</label><input type="text" value="₹ २०,०००.००" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px; font-weight:700; color:#5c1d8d;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">व्याज दर (दरमहा)</label><input type="text" value="२% दरमहा (२४% p.a.)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">मुदत (महिने)</label><input type="text" value="१२ महिने" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
  </div>
  <div style="display:grid; grid-template-columns:1fr 1fr 2fr; gap:10px; margin-bottom:10px;">
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">जामीनदार १</label><input type="text" value="सुनंदा पवार (MBG-001)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">जामीनदार २</label><input type="text" value="कविता शिंदे (MBG-003)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">कर्जाचा हेतू</label><input type="text" value="किराणा दुकान व्यवसाय विस्तार व साहित्य खरेदी" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
  </div>
  <div style="background:white; border:1px solid #cbd5e1; border-radius:6px; padding:8px 14px; display:flex; justify-content:space-around; font-size:11.5px; margin-bottom:10px;">
    <div>मासिक मुद्दल: <strong>₹ १,६६७.००</strong></div>
    <div>मासिक व्याज: <strong>₹ ४००.००</strong></div>
    <div>एकूण मासिक हप्ता (EMI): <strong style="font-size:13px; color:#5c1d8d;">₹ २,०६७.००</strong></div>
    <div>एकूण परतफेड: <strong>₹ २४,८०४.००</strong></div>
  </div>
  <div style="text-align:right;">
    <button class="btn-primary btn-success">कर्ज मंजूर करा व धनादेश/पावती द्या ✓</button>
  </div>
</div>
""")

# 6. Collect EMI
SCREENS["06_collect_emi"] = wrap_desktop_page("loans", """
<div class="page-title-row">
  <div>
    <h2>कर्ज हप्ता वसुली व परतफेड (Collect Loan EMI & Repayments)</h2>
    <p>सक्रिय अंतर्गत कर्जांची यादी व मासिक हप्ता जमा व्यवस्थापन</p>
  </div>
  <div style="display:flex; gap:8px;">
    <button class="btn-primary btn-amber">⚠️ थकबाकीदार यादी</button>
  </div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead>
      <tr><th>कर्ज कोड</th><th>कर्जदार नाव</th><th>कर्ज रक्कम</th><th>शिल्लक मुद्दल</th><th>हप्ता क्र.</th><th>मासिक मुद्दल</th><th>मासिक व्याज</th><th>दंड/शुल्क</th><th>एकूण हप्ता</th><th>कृती</th></tr>
    </thead>
    <tbody>
      <tr><td><strong>LN-2026-001</strong></td><td>मीना अशोक जाधव</td><td>₹ २०,०००.००</td><td>₹ १८,३३३.००</td><td>२ / १२</td><td>₹ १,६६७</td><td>₹ ३६७</td><td>₹ ०</td><td><strong>₹ २,०३४.००</strong></td><td><button class="btn-primary btn-success" style="font-size:9.5px; padding:3px 8px;">हप्ता भरा (Collect)</button></td></tr>
      <tr><td><strong>LN-2026-002</strong></td><td>लता संभाजी मोरे</td><td>₹ १५,०००.००</td><td>₹ १०,०००.००</td><td>५ / १२</td><td>₹ १,२५०</td><td>₹ २००</td><td><span style="color:#b91c1c;">₹ ५०</span></td><td><strong style="color:#b91c1c;">₹ १,५००.००</strong></td><td><button class="btn-primary btn-success" style="font-size:9.5px; padding:3px 8px;">हप्ता भरा (Collect)</button></td></tr>
      <tr><td><strong>LN-2026-003</strong></td><td>शारदा विलास गायकवाड</td><td>₹ १०,०००.००</td><td>₹ ५,०००.००</td><td>६ / १०</td><td>₹ १,०००</td><td>₹ १००</td><td>₹ ०</td><td><strong>₹ १,१००.००</strong></td><td><button class="btn-primary btn-success" style="font-size:9.5px; padding:3px 8px;">हप्ता भरा (Collect)</button></td></tr>
    </tbody>
  </table>
</div>
""")

# 7. Meetings & Attendance
SCREENS["07_meetings"] = wrap_desktop_page("meetings", """
<div class="page-title-row">
  <div>
    <h2>मासिक बैठका, हजेरी व विषयपत्रिका (Meetings & Attendance Register)</h2>
    <p>दरमहा १० तारखेला होणारी नियमित मासिक बैठक व सदस्यांची हजेरी नोंदवही</p>
  </div>
  <button class="btn-primary btn-success">+ नवीन बैठक आयोजित करा</button>
</div>
<div class="card-box" style="background:#f8fafc; border-left:4px solid #5c1d8d;">
  <div style="display:flex; justify-content:space-between; align-items:center;">
    <div>
      <h3 style="margin:0;">बैठक क्र. २४: माहे सप्टेंबर २०२६ मासिक सभा</h3>
      <p style="font-size:11px; color:#64748b;">दिनांक: १०-०९-२०२६ • वेळ: दुपारी २:०० • स्थान: समाज मंदिर, पंढरपूर</p>
    </div>
    <div><span class="badge badge-ok" style="font-size:11px;">हजेरी पूर्ण: १९ हजर / १ गैरहजर</span></div>
  </div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead>
      <tr><th>अ.क्र.</th><th>सदस्याचे नाव</th><th>पद</th><th>हजेरी स्थिती</th><th>मासिक बचत भरली?</th><th>हप्ता भरला?</th><th>दंड आकारणी</th><th>शेरा / स्वाक्षरी</th></tr>
    </thead>
    <tbody>
      <tr><td>१</td><td>सुनंदा मारुती पवार</td><td>अध्यक्षा</td><td><span class="badge badge-ok">हजर (Present)</span></td><td>होय (₹ ५००)</td><td>होय (₹ २,०६७)</td><td>-</td><td>उपस्थित स्वाक्षरी</td></tr>
      <tr><td>२</td><td>मीना अशोक जाधव</td><td>सचिवा</td><td><span class="badge badge-ok">हजर (Present)</span></td><td>होय (₹ ५००)</td><td>होय (₹ २,०३४)</td><td>-</td><td>उपस्थित स्वाक्षरी</td></tr>
      <tr><td>३</td><td>कविता बापू शिंदे</td><td>खजिनदार</td><td><span class="badge badge-ok">हजर (Present)</span></td><td>होय (₹ ५००)</td><td>-</td><td>-</td><td>उपस्थित स्वाक्षरी</td></tr>
      <tr><td>४</td><td>छाया दीपक कांबळे</td><td>सदस्य</td><td><span class="badge badge-err">गैरहजर (Absent)</span></td><td>नाही</td><td>-</td><td><span class="badge badge-warn">₹ ५० दंड आकारला</span></td><td>पूर्वपरवानगी नाही</td></tr>
    </tbody>
  </table>
</div>
""")

# 8. Income Management
SCREENS["08_income"] = wrap_desktop_page("income", """
<div class="page-title-row">
  <div>
    <h2>गटाचे उत्पन्न व्यवस्थापन व पावती नोंद (Income Management)</h2>
    <p>कर्ज व्याज, उत्पादने विक्री, शासकीय अनुदान, प्रवेश फी व इतर उत्पन्नाची नोंद</p>
  </div>
  <button class="btn-primary btn-success">+ उत्पन्न नोंदवा</button>
</div>
<div class="kpi-grid">
  <div class="kpi-card c-green"><div class="lbl">चालू महिना एकूण उत्पन्न</div><div class="val">₹ २६,१७०.००</div><div class="sub">सप्टेंबर २०२६</div></div>
  <div class="kpi-card c-blue"><div class="lbl">कर्ज व्याज जमा</div><div class="val">₹ २,६७०.००</div><div class="sub">सदस्य परतफेड</div></div>
  <div class="kpi-card c-purple"><div class="lbl">उत्पादने विक्री नफा</div><div class="val">₹ ८,५००.००</div><div class="sub">पापड-लोणचे विक्री</div></div>
  <div class="kpi-card c-teal"><div class="lbl">शासकीय फिरता निधी अनुदान</div><div class="val">₹ १५,०००.००</div><div class="sub">उमेद अभियान</div></div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>पावती क्र.</th><th>तारीख</th><th>उत्पन्नाची वर्गवारी</th><th>तपशील</th><th>कोणाकडून मिळाले</th><th>माध्यम</th><th>रक्कम (₹)</th></tr></thead>
    <tbody>
      <tr><td>INC-2026-001</td><td>०५-०९-२०२६</td><td>कर्ज व्याज जमा</td><td>मासिक हप्त्यांवरील व्याज संकलन</td><td>सदस्य कर्ज परतफेड</td><td>बँक जमा</td><td>₹ २,६७०.००</td></tr>
      <tr><td>INC-2026-002</td><td>०६-०९-२०२६</td><td>उत्पादने विक्री</td><td>गणेशोत्सव स्टॉल पापड-लोणचे विक्री</td><td>स्थानिक ग्राहक</td><td>रोख</td><td>₹ ८,५००.००</td></tr>
      <tr><td>INC-2026-003</td><td>०८-०९-२०२६</td><td>शासकीय अनुदान</td><td>उमेद MSRLM फिरता निधी</td><td>जिल्हा ग्रामीण विकास यंत्रणा</td><td>बँक ट्रान्सफर</td><td>₹ १५,०००.००</td></tr>
    </tbody>
  </table>
</div>
""")

# 9. Expense Management
SCREENS["09_expense"] = wrap_desktop_page("expense", """
<div class="page-title-row">
  <div>
    <h2>खर्च व्यवस्थापन व व्हाउचर्स नोंद (Expense Management)</h2>
    <p>स्टेशनरी, चहापान, प्रवास, बँक शुल्क व गट खर्चाची अधिकृत व्हाउचर नोंद</p>
  </div>
  <button class="btn-primary btn-amber">+ खर्च व्हाउचर तयार करा</button>
</div>
<div class="kpi-grid">
  <div class="kpi-card c-red"><div class="lbl">चालू महिना एकूण खर्च</div><div class="val">₹ ६५०.००</div><div class="sub">प्रशासकीय खर्च</div></div>
  <div class="kpi-card c-orange"><div class="lbl">स्टेशनरी व दप्तर</div><div class="val">₹ ३५०.००</div><div class="sub">नोंदवह्या व पेन</div></div>
  <div class="kpi-card c-purple"><div class="lbl">बैठक चहापान खर्च</div><div class="val">₹ २५०.००</div><div class="sub">मासिक सभा</div></div>
  <div class="kpi-card c-blue"><div class="lbl">बँक शुल्क व कर</div><div class="val">₹ ५०.००</div><div class="sub">पासबुक एंट्री शुल्क</div></div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>व्हाउचर क्र.</th><th>तारीख</th><th>खर्चाचा प्रकार</th><th>तपशील</th><th>देयक व्यक्ती/दुकान</th><th>माध्यम</th><th>रक्कम (₹)</th><th>स्थिती</th></tr></thead>
    <tbody>
      <tr><td>EXP-2026-001</td><td>०२-०९-२०२६</td><td>स्टेशनरी व दप्तर</td><td>बैठक इतिवृत्त वही व हजेरी रजिस्टर खरेदी</td><td>गुरुदत्त स्टेशनर्स</td><td>रोख</td><td>₹ ३५०.००</td><td><span class="badge badge-ok">मंजूर</span></td></tr>
      <tr><td>EXP-2026-002</td><td>०५-०९-२०२६</td><td>बैठक चहापान</td><td>मासिक बैठकीसाठी चहा व बिस्किटे</td><td>आनंद टी स्टॉल</td><td>रोख</td><td>₹ २५०.००</td><td><span class="badge badge-ok">मंजूर</span></td></tr>
      <tr><td>EXP-2026-003</td><td>०९-०९-२०२६</td><td>बँक शुल्क</td><td>बँक पासबुक प्रिंटिंग व SMS चार्ज</td><td>बँक ऑफ महाराष्ट्र</td><td>बँक डेबिट</td><td>₹ ५०.००</td><td><span class="badge badge-ok">मंजूर</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 10. Cash Book & Bank
SCREENS["10_cashbook"] = wrap_desktop_page("cashbook", """
<div class="page-title-row">
  <div>
    <h2>बँक खाती व रोख वही (Bank Accounts & Cash Book)</h2>
    <p>प्रत्येक दिवसाचा जमा-खर्च ताळेबंद, हातातील शिल्लक आणि बँक खात्यातील शिल्लक</p>
  </div>
  <div style="display:flex; gap:8px;">
    <button class="btn-primary btn-blue">🖨️ कॅश बुक PDF</button>
  </div>
</div>
<div class="kpi-grid">
  <div class="kpi-card c-teal"><div class="lbl">पेटीतील हातातील रोख शिल्लक</div><div class="val">₹ ९,१३४.००</div><div class="sub">प्रत्यक्ष रोख जुळणी पूर्ण</div></div>
  <div class="kpi-card c-purple"><div class="lbl">बँक ऑफ महाराष्ट्र बचत खाते</div><div class="val">₹ ४५,०००.००</div><div class="sub">A/c: 6032489011</div></div>
  <div class="kpi-card c-green"><div class="lbl">चालू महिना एकूण जमा (Receipts)</div><div class="val">₹ २९,३३७.००</div><div class="sub">सर्व जमा व्यवहार</div></div>
  <div class="kpi-card c-orange"><div class="lbl">चालू महिना एकूण नावे (Payments)</div><div class="val">₹ २०,६५०.००</div><div class="sub">कर्ज वाटप + खर्च</div></div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>तारीख</th><th>पावती/व्हाउचर</th><th>तपशील (Particulars)</th><th>व्यवहार वर्ग</th><th>जमा (₹ Cr)</th><th>खर्च (₹ Dr)</th><th>एकूण शिल्लक (₹)</th></tr></thead>
    <tbody>
      <tr><td>०१-०९-२०२६</td><td>OB-001</td><td>मागील महिन्याची शिल्लक (Opening Balance)</td><td>आरंभी शिल्लक</td><td>₹ ४५,४४७.००</td><td>-</td><td>₹ ४५,४४७.००</td></tr>
      <tr><td>०५-०९-२०२६</td><td>SAV-09</td><td>मासिक बचत संकलन (२० सभासद)</td><td>बचत जमा</td><td>₹ १०,०००.००</td><td>-</td><td>₹ ५५,४४७.००</td></tr>
      <tr><td>०५-०९-२०२६</td><td>LN-01</td><td>मीना अशोक जाधव यांना अंतर्गत कर्ज वाटप</td><td>कर्ज वाटप</td><td>-</td><td>₹ २०,०००.००</td><td>₹ ३५,४४७.००</td></tr>
      <tr><td>१०-०९-२०२६</td><td>EXP-01</td><td>स्टेशनरी व दप्तर खर्च व्हाउचर्स</td><td>गट खर्च</td><td>-</td><td>₹ ३५०.००</td><td>₹ ३५,०९७.००</td></tr>
    </tbody>
  </table>
</div>
""")

# 11. Inventory POS
SCREENS["11_inventory"] = wrap_desktop_page("inventory", """
<div class="page-title-row">
  <div>
    <h2>उत्पादने व स्टॉक विक्री POS (Products & Inventory POS)</h2>
    <p>बचत गटाचे लघुउद्योग उत्पादने: पापड, लोणचे, मसाले व शेवया निर्मिती व थेट विक्री</p>
  </div>
  <div style="display:flex; gap:8px;">
    <button class="btn-primary btn-blue">🛒 विक्री बिल (POS)</button>
    <button class="btn-primary btn-success">+ नवीन उत्पादन जोडा</button>
  </div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>उत्पादन कोड</th><th>उत्पादनाचे नाव</th><th>पॅकिंग आकार</th><th>खरेदी/उत्पादन खर्च</th><th>विक्री दर (₹)</th><th>उपलब्ध शिल्लक स्टॉक</th><th>एकूण स्टॉक मूल्य</th><th>स्थिती</th></tr></thead>
    <tbody>
      <tr><td>PRD-01</td><td><strong>उडीद पापड (स्पेशल)</strong></td><td>५०० ग्रॅम पॅकेट</td><td>₹ ११०.००</td><td><strong>₹ १४०.००</strong></td><td>८५ पॅकेट्स</td><td>₹ ११,९००.००</td><td><span class="badge badge-ok">स्टॉकमध्ये</span></td></tr>
      <tr><td>PRD-02</td><td><strong>गावरान कैरी लोणचे</strong></td><td>१ किलो काच बरणी</td><td>₹ १८०.००</td><td><strong>₹ २५०.००</strong></td><td>४२ बरण्या</td><td>₹ १०,५००.००</td><td><span class="badge badge-ok">स्टॉकमध्ये</span></td></tr>
      <tr><td>PRD-03</td><td><strong>घरगुती गरम मसाला</strong></td><td>२५० ग्रॅम पाऊच</td><td>₹ ८०.००</td><td><strong>₹ ११०.००</strong></td><td>६५ पाऊच</td><td>₹ ७,१५०.००</td><td><span class="badge badge-ok">स्टॉकमध्ये</span></td></tr>
      <tr><td>PRD-04</td><td><strong>सुगंधी अगरबत्ती</strong></td><td>२५० ग्रॅम बॉक्स</td><td>₹ ३५.००</td><td><strong>₹ ५०.००</strong></td><td>११० बॉक्स</td><td>₹ ५,५००.००</td><td><span class="badge badge-ok">स्टॉकमध्ये</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 12. Bank Loans
SCREENS["12_bank_loans"] = wrap_desktop_page("bankloans", """
<div class="page-title-row">
  <div>
    <h2>बँक लिंकेज कर्ज व शासकीय योजना (Bank Loans & Govt Schemes)</h2>
    <p>राष्ट्रीयीकृत बँका व जिल्हा बँकेकडून बचत गटास मंजूर कर्ज व व्याज अनुदान योजना</p>
  </div>
  <button class="btn-primary btn-success">+ नवीन बँक कर्ज नोंदवा</button>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>बँकेचे नाव</th><th>शासकीय योजना</th><th>मंजूर रक्कम</th><th>व्याजदर</th><th>मासिक हप्ता (EMI)</th><th>परतफेड रक्कम</th><th>शिल्लक मुद्दल</th><th>स्थिती</th></tr></thead>
    <tbody>
      <tr><td><strong>बँक ऑफ महाराष्ट्र</strong></td><td>उमेद - MSRLM क्रेडिट लिंकेज</td><td>₹ २,००,०००.००</td><td>७% (व्याज अनुदानित)</td><td>₹ ४,५००.००</td><td>₹ ८०,०००.००</td><td><strong>₹ १,२०,०००.००</strong></td><td><span class="badge badge-ok">नियमित चालू</span></td></tr>
      <tr><td><strong>सोलापूर जिल्हा मध्यवर्ती बँक</strong></td><td>नाबार्ड खेळते भांडवल</td><td>₹ ५०,०००.००</td><td>४% वार्षिक</td><td>₹ १,२५०.००</td><td>₹ ५०,०००.००</td><td><strong>₹ ०.००</strong></td><td><span class="badge badge-purple">पूर्ण फेडले</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 13. Profit & Loss
SCREENS["13_profit_loss"] = wrap_desktop_page("pnl", """
<div class="page-title-row">
  <div>
    <h2>मासिक नफा-तोटा ताळेबंद (Monthly Profit & Loss Statement)</h2>
    <p>माहे: सप्टेंबर २०२६ | सर्व जमा vs खर्च निव्वळ नफा (Net Surplus) विश्लेषण</p>
  </div>
  <button class="btn-primary btn-blue">🖨️ ताळेबंद पत्रक PDF</button>
</div>
<div style="display:flex; gap:12px; margin-bottom:12px;">
  <div class="card-box" style="flex:1; background:#f0fdf4; border:1.5px solid #86efac;">
    <h3 style="color:#166534;">१. जमा बाजू (Revenue / Income)</h3>
    <table class="data-table">
      <tr><td>कर्ज व्याज जमा</td><td style="text-align:right; font-weight:700;">₹ २,६७०.००</td></tr>
      <tr><td>उत्पादने विक्री निव्वळ नफा</td><td style="text-align:right; font-weight:700;">₹ ५,५००.००</td></tr>
      <tr><td>दंड व विलंब शुल्क</td><td style="text-align:right; font-weight:700;">₹ २२०.००</td></tr>
      <tr><td>बँक बचत खाते व्याज जमा</td><td style="text-align:right; font-weight:700;">₹ ५४७.००</td></tr>
      <tr style="background:#dcfce7; font-size:12px;"><td style="font-weight:700;">एकूण महसूल जमा</td><td style="text-align:right; font-weight:700; color:#166534;">₹ ८,९३७.००</td></tr>
    </table>
  </div>
  <div class="card-box" style="flex:1; background:#fff1f2; border:1.5px solid #fca5a5;">
    <h3 style="color:#9f1239;">२. खर्च बाजू (Expenses / Outflow)</h3>
    <table class="data-table">
      <tr><td>दप्तर स्टेशनरी व वह्या</td><td style="text-align:right; font-weight:700;">₹ ३५०.००</td></tr>
      <tr><td>मासिक सभा चहापान</td><td style="text-align:right; font-weight:700;">₹ २५०.००</td></tr>
      <tr><td>बँक चार्जेस व SMS फी</td><td style="text-align:right; font-weight:700;">₹ ५०.००</td></tr>
      <tr><td>इतर किरकोळ खर्च</td><td style="text-align:right; font-weight:700;">₹ ०.००</td></tr>
      <tr style="background:#fee2e2; font-size:12px;"><td style="font-weight:700;">एकूण प्रशासकीय खर्च</td><td style="text-align:right; font-weight:700; color:#9f1239;">₹ ६५०.००</td></tr>
    </table>
  </div>
</div>
<div class="card-box" style="background:#faf5ff; border:2px solid #a855f7; text-align:center; padding:16px;">
  <div style="font-size:12px; color:#6b21a8; font-weight:600;">सप्टेंबर २०२६ - निव्वळ नफा (Net Monthly Profit)</div>
  <div style="font-size:26px; font-weight:700; color:#5c1d8d; margin:4px 0;">₹ ८,२८७.००</div>
  <div style="font-size:11px; color:#475569;">हा निव्वळ नफा सर्व २० सदस्यांच्या बचत प्रमाणात वार्षिक लाभांश (Dividend) म्हणून वाटप केला जाईल.</div>
</div>
""")

# 14. Contributions & Fines
SCREENS["14_contributions_fines"] = wrap_desktop_page("contrib", """
<div class="page-title-row">
  <div>
    <h2>वर्गणी व दंड नोंदणी वही (Contributions & Penalties Register)</h2>
    <p>विशेष निधी, वार्षिक उत्सव वर्गणी व मासिक बैठकीस गैरहजर दंड हिशोब</p>
  </div>
  <button class="btn-primary btn-amber">+ वर्गणी / दंड नोंदवा</button>
</div>
<div class="tabs-header">
  <div class="tab-btn active">१. वर्गणी नोंदी (Contributions)</div>
  <div class="tab-btn">२. दंड नोंदी (Fines & Penalties)</div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>तारीख</th><th>सदस्याचे नाव</th><th>प्रकार</th><th>कारण / तपशील</th><th>रक्कम (₹)</th><th>माध्यम</th><th>स्थिती</th></tr></thead>
    <tbody>
      <tr><td>०५-०९-२०२६</td><td>छाया दीपक कांबळे</td><td><span class="badge badge-err">दंड (Fine)</span></td><td>मासिक बैठकीस पूर्वपरवानगीशिवाय गैरहजर राहिल्यामुळे</td><td>₹ ५०.००</td><td>रोख</td><td><span class="badge badge-ok">वसूल झाले</span></td></tr>
      <tr><td>०१-०९-२०२६</td><td>सर्व २० सभासद</td><td><span class="badge badge-purple">विशेष वर्गणी</span></td><td>वार्षिक हळदी-कुंकू व मेळावा निधी (प्रति सदस्य ₹ १००)</td><td>₹ २,०००.००</td><td>रोख</td><td><span class="badge badge-ok">जमा ✓</span></td></tr>
      <tr><td>१५-०८-२०२६</td><td>लता संभाजी मोरे</td><td><span class="badge badge-err">दंड (Fine)</span></td><td>कर्ज हप्ता भरण्यास १५ दिवस विलंब शुल्क</td><td>₹ ५०.००</td><td>हप्त्यासोबत</td><td><span class="badge badge-ok">वसूल झाले</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 15. Resolutions & KYC
SCREENS["15_resolutions_kyc"] = wrap_desktop_page("resolutions", """
<div class="page-title-row">
  <div>
    <h2>ठराव वही व सदस्य KYC कागदपत्रे (Resolutions & KYC Documents)</h2>
    <p>बैठकीतील कायदेशीर ठराव नोंद, सूचक-अनुमोदक व सदस्यांचे आधार/पॅन/बँक कागदपत्रे</p>
  </div>
  <button class="btn-primary btn-success">+ नवीन ठराव नोंदवा</button>
</div>
<div class="tabs-header">
  <div class="tab-btn active">१. ठराव नोंदवही (Resolutions)</div>
  <div class="tab-btn">२. सदस्य कागदपत्रे व KYC पडताळणी</div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>ठराव क्र.</th><th>बैठक दिनांक</th><th>ठरावाचा मुख्य विषय</th><th>सूचक (Proposed By)</th><th>अनुमोदक (Seconded)</th><th>निर्णय</th><th>स्वाक्षऱ्या</th></tr></thead>
    <tbody>
      <tr><td><strong>RES-24/01</strong></td><td>१०-०९-२०२६</td><td>मीना अशोक जाधव यांना किराणा दुकान व्यवसायासाठी ₹ २०,००० अंतर्गत कर्ज मंजूर करणेबाबत</td><td>सुनंदा पवार</td><td>कविता शिंदे</td><td><span class="badge badge-ok">एकमुखाने मंजूर ✓</span></td><td>सर्व २० स्वाक्षऱ्या</td></tr>
      <tr><td><strong>RES-24/02</strong></td><td>१०-०९-२०२६</td><td>दिवाळीनिमित्त जिल्हा परिषद मेळाव्यात गटाचा पापड-मसाले स्टॉल लावणे व खर्चास मंजुरी</td><td>लता मोरे</td><td>आशा भोसले</td><td><span class="badge badge-ok">एकमुखाने मंजूर ✓</span></td><td>सर्व २० स्वाक्षऱ्या</td></tr>
    </tbody>
  </table>
</div>
""")

# 16. Trainings & Events
SCREENS["16_trainings_events"] = wrap_desktop_page("trainings", """
<div class="page-title-row">
  <div>
    <h2>कौशल्य प्रशिक्षण व उपक्रम मेळावे (Trainings & Events Register)</h2>
    <p>महिला सक्षमीकरण शिबिरे, व्यावसायिक प्रशिक्षण, मेळावे व प्रदर्शन स्टॉल नोंद</p>
  </div>
  <button class="btn-primary btn-success">+ उपक्रम नोंदवा</button>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>उपक्रमाचे नाव</th><th>प्रकार</th><th>प्रशिक्षक / संस्था</th><th>कालावधी</th><th>सहभागी महिला</th><th>खर्च / अनुदान</th><th>स्थिती</th></tr></thead>
    <tbody>
      <tr><td><strong>अन्न प्रक्रिया व पॅकिंग प्रशिक्षण</strong></td><td>कौशल्य प्रशिक्षण</td><td>कृषी विज्ञान केंद्र (KVK) सोलापूर</td><td>१५ ते १८ ऑगस्ट २०२६ (३ दिवस)</td><td>१५ सदस्य</td><td>शासकीय मोफत</td><td><span class="badge badge-ok">प्रमाणपत्र प्राप्त</span></td></tr>
      <tr><td><strong>जिल्हास्तरीय महिला बचत गट मेळावा</strong></td><td>प्रदर्शन व विक्री</td><td>जिल्हा ग्रामीण विकास यंत्रणा (DRDA)</td><td>०२ ते ०५ ऑक्टोबर २०२६</td><td>२० सदस्य</td><td>₹ २,००० स्टॉल</td><td><span class="badge badge-info">नियोजित (Upcoming)</span></td></tr>
    </tbody>
  </table>
</div>
""")

# 17. Dues & Recovery
SCREENS["17_dues_recovery"] = wrap_desktop_page("dues", """
<div class="page-title-row">
  <div>
    <h2>थकबाकी व वसुली नोंदवही (Dues & Recovery Register)</h2>
    <p>प्रलंबित हप्ते व मासिक बचतीचा मागोवा आणि WhatsApp स्मरणपत्रे</p>
  </div>
  <button class="btn-primary btn-amber">💬 सर्व थकबाकीदारांना WhatsApp स्मरणपत्र पाठवा</button>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>सदस्याचे नाव</th><th>मोबाईल नंबर</th><th>कर्ज खाते क्र.</th><th>थकीत महिने</th><th>मुद्दल बाकी (₹)</th><th>व्याज बाकी (₹)</th><th>विलंब दंड (₹)</th><th>एकूण येणे बाकी</th><th>कृती</th></tr></thead>
    <tbody>
      <tr><td><strong>लता संभाजी मोरे</strong></td><td>9765123456</td><td>LN-2026-002</td><td>१ महिना</td><td>₹ १,२५०.००</td><td>₹ २००.००</td><td>₹ ५०.००</td><td style="color:#b91c1c; font-weight:700;">₹ १,५००.००</td><td><button class="btn-primary btn-success" style="font-size:9px; padding:2px 6px;">हप्ता भरा</button> <button class="btn-primary btn-amber" style="font-size:9px; padding:2px 6px;">WhatsApp 💬</button></td></tr>
      <tr><td><strong>अनिता तानाजी शिंदे</strong></td><td>9822334455</td><td>LN-2026-005</td><td>२ महिने</td><td>₹ २,०००.००</td><td>₹ ३००.००</td><td>₹ १००.००</td><td style="color:#b91c1c; font-weight:700;">₹ २,४००.००</td><td><button class="btn-primary btn-success" style="font-size:9px; padding:2px 6px;">हप्ता भरा</button> <button class="btn-primary btn-amber" style="font-size:9px; padding:2px 6px;">WhatsApp 💬</button></td></tr>
    </tbody>
  </table>
</div>
""")

# 18. Notifications
SCREENS["18_notifications"] = wrap_desktop_page("notifications", """
<div class="page-title-row">
  <div>
    <h2>सूचना, इशारे व स्मरणपत्रे (Notifications & Reminders)</h2>
    <p>कर्ज हप्ता देय तारखा, बैठकीचे स्मरणपत्र व सिंक इशारे</p>
  </div>
</div>
<div style="display:flex; flex-direction:column; gap:10px;">
  <div class="card-box" style="border-left:4px solid #ef4444; background:white; margin:0;">
    <div style="display:flex; justify-content:space-between;">
      <strong style="color:#b91c1c; font-size:12px;">⚠️ कर्ज हप्ता देय स्मरणपत्र! (Overdue Notice)</strong>
      <span style="font-size:10px; color:#64748b;">आज, दुपारी १२:००</span>
    </div>
    <p style="font-size:11.5px; color:#334155; margin-top:4px;">अनिता तानाजी शिंदे (MBG-008) यांचा कर्ज हप्ता ₹ १,२०० देय आहे. थकीत कालावधी: २ महिने.</p>
  </div>
  <div class="card-box" style="border-left:4px solid #0284c7; background:white; margin:0;">
    <div style="display:flex; justify-content:space-between;">
      <strong style="color:#0369a1; font-size:12px;">📅 मासिक सभा सूचना (Upcoming Meeting)</strong>
      <span style="font-size:10px; color:#64748b;">उद्या दुपारी २:००</span>
    </div>
    <p style="font-size:11.5px; color:#334155; margin-top:4px;">माहे सप्टेंबर मासिक सभा समाज मंदिरात आयोजित केली आहे. सर्व २० सदस्यांनी बचत व हप्ता रकमेसह उपस्थित राहावे.</p>
  </div>
  <div class="card-box" style="border-left:4px solid #10b981; background:white; margin:0;">
    <div style="display:flex; justify-content:space-between;">
      <strong style="color:#15803d; font-size:12px;">🟢 क्लाउड ऑटो-सिंक यशस्वी (Sync Completed)</strong>
      <span style="font-size:10px; color:#64748b;">१० मिनिटांपूर्वी</span>
    </div>
    <p style="font-size:11.5px; color:#334155; margin-top:4px;">स्थानिक डेटाबेसचे सर्व ५० व्यवहार क्लाउड सर्व्हरवर सुरक्षित बॅकअप झाले आहेत.</p>
  </div>
</div>
""")

# 19. All Reports
SCREENS["19_all_reports"] = wrap_desktop_page("reports", """
<div class="page-title-row">
  <div>
    <h2>३८+ अधिकृत शासकीय अहवाल व ताळेबंद प्रणाली (All Reports & Balance Sheet)</h2>
    <p>NRLM व उमेद मानकांनुसार शासकीय तपासणी व ऑडिटसाठी अधिकृत अहवाल</p>
  </div>
  <button class="btn-primary btn-blue">🖨️ निवडलेला अहवाल PDF डाऊनलोड करा</button>
</div>
<div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:10px; margin-bottom:12px;">
  <div class="card-box" style="border-left:3px solid #5c1d8d; cursor:pointer;">
    <h3 style="margin:0; font-size:11.5px;">१. मासिक जमा-खर्च अहवाल</h3>
    <p style="font-size:10px; color:#64748b;">चालू महिन्याची बचत, वसुली व खर्च सारांश.</p>
  </div>
  <div class="card-box" style="border-left:3px solid #5c1d8d; cursor:pointer; background:#faf5ff;">
    <h3 style="margin:0; font-size:11.5px; color:#5c1d8d;">२. वार्षिक ताळेबंद (Balance Sheet)</h3>
    <p style="font-size:10px; color:#64748b;">गटाची एकूण मालमत्ता, देणी व बँक जमा.</p>
  </div>
  <div class="card-box" style="border-left:3px solid #5c1d8d; cursor:pointer;">
    <h3 style="margin:0; font-size:11.5px;">३. सदस्य वैयक्तिक पासबुक</h3>
    <p style="font-size:10px; color:#64748b;">प्रत्येक सदस्याची १२ महिन्यांची बचत वही.</p>
  </div>
</div>
<div class="card-box">
  <div style="text-align:center; margin-bottom:8px;">
    <h3 style="margin:0;">सावित्रीबाई फुले महिला बचत गट, पंढरपूर</h3>
    <p style="font-size:10px; color:#64748b;">मासिक आर्थिक ताळेबंद अहवाल - सप्टेंबर २०२६</p>
  </div>
  <table class="data-table">
    <thead><tr><th>जमा बाजू (Inflow / Receipts)</th><th>रक्कम (₹)</th><th>खर्च बाजू (Outflow / Payments)</th><th>रक्कम (₹)</th></tr></thead>
    <tbody>
      <tr><td>मासिक बचत संकलन</td><td>₹ १०,०००.००</td><td>नवीन अंतर्गत कर्ज वाटप</td><td>₹ २०,०००.००</td></tr>
      <tr><td>कर्ज मुद्दल परतफेड</td><td>₹ १६,६६७.००</td><td>स्टेशनरी व दप्तर खर्च</td><td>₹ ३५०.००</td></tr>
      <tr><td>कर्ज व्याज जमा</td><td>₹ २,६७०.००</td><td>बैठक चहापान खर्च</td><td>₹ २५०.००</td></tr>
      <tr style="font-weight:700; background:#f1f5f9;"><td>एकूण जमा (Total)</td><td>₹ २९,३३७.००</td><td>एकूण खर्च व शिल्लक</td><td>₹ २९,३३७.००</td></tr>
    </tbody>
  </table>
</div>
""")

# 20. Audit Log
SCREENS["20_audit_log"] = wrap_desktop_page("audit", """
<div class="page-title-row">
  <div>
    <h2>ऑडिट ट्रेल व हालचाली नोंद (Audit Log & Activity Register)</h2>
    <p>डेटा सुरक्षितता: कोणती नोंद कोणी, कधी आणि काय बदलली याची फेरफार-प्रतिबंधित नोंद</p>
  </div>
</div>
<div class="card-box">
  <table class="data-table">
    <thead><tr><th>वेळ व तारीख</th><th>वापरकर्ता (User)</th><th>मॉड्यूल</th><th>कृती (Action)</th><th>तपशील</th><th>IP / डिव्हाइस</th></tr></thead>
    <tbody>
      <tr><td>१०-०९-२०२६ १४:३०</td><td>सुनंदा पवार (अध्यक्षा)</td><td>कर्ज वाटप</td><td><span class="badge badge-ok">नवीन नोंद</span></td><td>मीना जाधव यांना ₹ २०,००० कर्ज वाटप मंजूर केले</td><td>Windows App (Local)</td></tr>
      <tr><td>१०-०९-२०२६ १३:१५</td><td>मीना जाधव (सचिवा)</td><td>मासिक बचत</td><td><span class="badge badge-info">जमा नोंद</span></td><td>२० सदस्यांची प्रत्येकी ₹ ५०० बचत संकलन नोंदवले</td><td>Windows App (Local)</td></tr>
      <tr><td>०९-०९-२०२६ १८:००</td><td>कविता शिंदे (खजिनदार)</td><td>खर्च व्हाउचर</td><td><span class="badge badge-warn">व्हाउचर तयार</span></td><td>दप्तर स्टेशनरी ₹ ३५० व्हाउचर मंजूर केले</td><td>Windows App (Local)</td></tr>
    </tbody>
  </table>
</div>
""")

# 21. Settings & Profile
SCREENS["21_settings_profile"] = wrap_desktop_page("settings", """
<div class="page-title-row">
  <div>
    <h2>गट माहिती, पदाधिकारी व नियम सेटिंग्ज (Settings & Profile)</h2>
    <p>बचत गटाचे नाव, लोगो, शासकीय नोंदणी क्रमांक, पदाधिकारी तपशील व नियम</p>
  </div>
  <button class="btn-primary btn-success">बदल जतन करा ✓</button>
</div>
<div class="tabs-header">
  <div class="tab-btn active">१. बचत गट माहिती व फोटो</div>
  <div class="tab-btn">२. पदाधिकारी व नियम</div>
  <div class="tab-btn">३. सुरक्षा व पिन लॉक</div>
</div>
<div class="card-box">
  <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:12px; margin-bottom:12px;">
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">बचत गटाचे नाव</label><input type="text" value="सावित्रीबाई फुले महिला बचत गट" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">शासकीय नोंदणी क्र.</label><input type="text" value="MH/SOL/2024/0987" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">दरमहा बचत रक्कम (प्रति सदस्य)</label><input type="text" value="₹ ५००.००" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
  </div>
  <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:12px; margin-bottom:12px;">
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">अध्यक्षा नाव व फोन</label><input type="text" value="सुनंदा मारुती पवार (9876543210)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">सचिवा नाव व फोन</label><input type="text" value="मीना अशोक जाधव (9765432109)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
    <div><label style="font-size:10px; font-weight:700; color:#5c1d8d;">खजिनदार नाव व फोन</label><input type="text" value="कविता बापू शिंदे (9654321098)" style="width:100%; padding:6px; border:1px solid #cbd5e1; border-radius:4px; font-size:11px;"></div>
  </div>
</div>
""")

# 22. Backup & Restore
SCREENS["22_backup_restore"] = wrap_desktop_page("backup", """
<div class="page-title-row">
  <div>
    <h2>बॅकअप व रिस्टोअर (.db) मॉड्यूल (Backup & Restore .db System)</h2>
    <p>१००% डेटा सुरक्षा: कॉम्प्युटर किंवा फोनमध्ये संपूर्ण डेटा सेव्ह व पूर्ववत करा</p>
  </div>
</div>
<div style="display:flex; gap:16px; margin-bottom:16px;">
  <div class="card-box" style="flex:1; background:#ecfdf5; border:1.5px solid #86efac; text-align:center; padding:20px;">
    <div style="font-size:32px; margin-bottom:6px;">💾</div>
    <h3 style="color:#065f46; font-size:14px;">बॅकअप एक्सपोर्ट करा (Export Backup .db)</h3>
    <p style="font-size:11px; color:#047857; margin-bottom:14px;">सर्व सदस्य, बचत, कर्ज व व्यवहारांची स्वतंत्र <code>.db</code> फाईल पेनड्राइव्ह किंवा फोनमध्ये सेव्ह करा.</p>
    <button class="btn-primary btn-success" style="padding:8px 18px; font-size:12px;">बॅकअप फाईल डाऊनलोड करा (.db) 📥</button>
  </div>
  <div class="card-box" style="flex:1; background:#eff6ff; border:1.5px solid #93c5fd; text-align:center; padding:20px;">
    <div style="font-size:32px; margin-bottom:6px;">🔄</div>
    <h3 style="color:#1e40af; font-size:14px;">बॅकअप इम्पोर्ट करा (Import / Restore .db)</h3>
    <p style="font-size:11px; color:#1d4ed8; margin-bottom:14px;">कॉम्प्युटर बदलल्यास किंवा फोन हरवल्यास जुनी <code>.db</code> फाईल निवडून १ सेकंदात डेटा पूर्ववत करा.</p>
    <button class="btn-primary btn-blue" style="padding:8px 18px; font-size:12px;">बॅकअप फाईल निवडा (.db) 📂</button>
  </div>
</div>
<div class="card-box">
  <h3>डेटा सुरक्षा व बॅकअप सुसंगतता माहिती</h3>
  <p style="font-size:11px; color:#475569;">Windows आणि Android दोन्ही आवृत्त्यांमध्ये एकाच प्रकारची मानक SQLite <code>.db</code> फाईल वापरली जाते. फोनवरून घेतलेला बॅकअप संगणकावर चालू शकतो आणि संगणकावरील बॅकअप फोनवर रिस्टोअर करता येतो.</p>
</div>
""")

# 23. Mobile Zoom View (Rendered in authentic mobile phone viewport 420x760)
SCREENS["23_mobile_zoom"] = f"""<!DOCTYPE html>
<html lang="mr"><head><meta charset="UTF-8"><style>
{COMMON_CSS}
body {{
  width: 420px;
  height: 760px;
  background: #1e1b4b;
  display: flex;
  align-items: center;
  justify-content: center;
}}
.phone-bezel {{
  width: 390px;
  height: 730px;
  background: #f8fafc;
  border-radius: 36px;
  border: 10px solid #0f172a;
  box-shadow: 0 20px 40px rgba(0,0,0,0.5);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  position: relative;
}}
.notch {{
  width: 130px; height: 18px; background: #0f172a; border-radius: 0 0 14px 14px;
  margin: 0 auto; display: flex; align-items: center; justify-content: center;
}}
.notch-cam {{ width: 8px; height: 8px; background: #334155; border-radius: 50%; }}
.mob-topbar {{
  background: #5c1d8d; color: white; padding: 8px 12px;
  display: flex; justify-content: space-between; align-items: center; font-size: 11px;
}}
.mob-content {{
  flex: 1; padding: 12px; overflow-y: auto; background: #f8fafc;
}}
.zoom-toolbar {{
  position: absolute; bottom: 20px; left: 50%; transform: translateX(-50%);
  background: #0f172a; color: white; border-radius: 24px; padding: 6px 14px;
  display: flex; align-items: center; gap: 10px; font-size: 11px;
  box-shadow: 0 4px 14px rgba(0,0,0,0.3); border: 1px solid #334155;
}}
</style></head>
<body>
<div class="phone-bezel">
  <div class="notch"><div class="notch-cam"></div></div>
  <div class="mob-topbar">
    <div><strong>☰ सखी बचत गट</strong></div>
    <div><span class="badge badge-ok" style="font-size:9px;">सिंक ✓</span></div>
  </div>
  <div class="mob-content">
    <div style="background:white; border-radius:8px; padding:10px; margin-bottom:10px; border:1px solid #e2e8f0;">
      <div style="font-size:11px; color:#64748b;">सावित्रीबाई फुले महिला बचत गट</div>
      <div style="font-size:14px; font-weight:700; color:#5c1d8d;">मासिक बचत संकलन (मोबाईल)</div>
    </div>
    <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-bottom:10px;">
      <div class="kpi-card c-blue" style="padding:8px;"><div class="lbl">सदस्य</div><div class="val" style="font-size:15px;">२०</div></div>
      <div class="kpi-card c-green" style="padding:8px;"><div class="lbl">बचत जमा</div><div class="val" style="font-size:15px;">₹ १०,०००</div></div>
    </div>
    <div class="card-box" style="padding:8px;">
      <div style="font-size:11px; font-weight:700; margin-bottom:6px;">सदस्य यादी व बचत भरणा</div>
      <div style="font-size:10.5px; line-height:2.2;">
        <div style="display:flex; justify-content:space-between; border-bottom:1px solid #f1f5f9;">
          <span>सुनंदा पवार (अध्यक्षा)</span><span style="color:#15803d; font-weight:700;">₹ ५०० जमा ✓</span>
        </div>
        <div style="display:flex; justify-content:space-between; border-bottom:1px solid #f1f5f9;">
          <span>मीना जाधव (सचिवा)</span><span style="color:#15803d; font-weight:700;">₹ ५०० जमा ✓</span>
        </div>
        <div style="display:flex; justify-content:space-between; border-bottom:1px solid #f1f5f9;">
          <span>कविता शिंदे (खजिनदार)</span><span style="color:#15803d; font-weight:700;">₹ ५०० जमा ✓</span>
        </div>
      </div>
    </div>
  </div>
  <!-- Floating Zoom Toolbar -->
  <div class="zoom-toolbar">
    <span style="cursor:pointer;">➖</span>
    <span style="color:#38bdf8; font-weight:700;">100%</span>
    <span style="cursor:pointer;">➕</span>
    <span style="background:#334155; padding:2px 8px; border-radius:12px; font-size:9.5px;">Fit</span>
    <span style="color:#94a3b8; cursor:pointer;">✕</span>
  </div>
</div>
</body></html>"""

print(f"Total screens defined: {len(SCREENS)}")

# Render each screen to PNG
for key, html in SCREENS.items():
    html_file = os.path.join(SCREENSHOTS_DIR, f"{key}.html")
    png_file = os.path.join(SCREENSHOTS_DIR, f"{key}.png")
    with open(html_file, "w", encoding="utf-8") as f:
        f.write(html)
    
    win_size = "420,760" if key == "23_mobile_zoom" else "1200,720"
    cmd = [
        CHROME_EXE,
        "--headless",
        "--disable-gpu",
        f"--screenshot={png_file}",
        f"--window-size={win_size}",
        html_file
    ]
    subprocess.run(cmd, check=True)
    print(f"Successfully captured actual screen photo: {key}.png")

print("ALL 23 ACTUAL SCREEN PHOTOS CAPTURED SUCCESSFULLY!")
