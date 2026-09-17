# -*- coding: utf-8 -*-
"""
Script to test rendering full-screen UI photo screenshots.
"""
import os
import subprocess

CSS_BASE = """
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
.win-titlebar .title {
  display: flex;
  align-items: center;
  gap: 8px;
}
.win-controls {
  display: flex;
  gap: 12px;
  font-size: 13px;
  color: #94a3b8;
}
.app-topbar {
  background: #ffffff;
  border-bottom: 1px solid #e2e8f0;
  height: 52px;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.app-topbar .brand {
  display: flex;
  align-items: center;
  gap: 10px;
}
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
.app-topbar .brand-text h1 {
  font-size: 14px;
  font-weight: 700;
  color: #1e1b4b;
}
.app-topbar .brand-text p {
  font-size: 10.5px;
  color: #64748b;
}
.topbar-right {
  display: flex;
  align-items: center;
  gap: 14px;
}
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
.sync-badge .dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #22c55e;
}
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
  padding: 6px 10px;
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
.page-title-row h2 {
  font-size: 16px;
  font-weight: 700;
  color: #1e1b4b;
}
.page-title-row p {
  font-size: 11px;
  color: #64748b;
}
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
.card-box h3 {
  font-size: 12.5px;
  font-weight: 700;
  color: #1e1b4b;
  margin-bottom: 8px;
}
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
}
.btn-success { background: #10b981; }
.btn-outline { background: white; border: 1px solid #cbd5e1; color: #334155; }
"""

def generate_dashboard_html():
    return f"""<!DOCTYPE html>
<html lang="mr"><head><meta charset="UTF-8"><style>{CSS_BASE}</style></head>
<body>
<div class="window-frame">
  <div class="win-titlebar">
    <div class="title">
      <span>💠</span>
      <span>सखी महिला बचत गट व्यवस्थापन प्रणाली v2.0 - [सावित्रीबाई फुले महिला बचत गट, पंढरपूर]</span>
    </div>
    <div class="win-controls"><span>🗕</span><span>🗖</span><span>✕</span></div>
  </div>
  <div class="app-topbar">
    <div class="brand">
      <div class="brand-icon">स</div>
      <div class="brand-text">
        <h1>सावित्रीबाई फुले महिला बचत गट</h1>
        <p>गावाचे नाव: पंढरपूर, जि. सोलापूर • नोंदणी क्र: MH/SOL/2024/0987</p>
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
    <div class="sidebar">
      <div class="sidebar-section">मुख्य व्यवस्थापन</div>
      <div class="nav-item active">📊 ३. मुख्य डॅशबोर्ड</div>
      <div class="nav-item">👥 ४. सदस्य व्यवस्थापन</div>
      <div class="nav-item">💰 ५. मासिक बचत नोंद</div>
      <div class="nav-item">💳 ६ व ७. कर्ज वाटप व वसुली</div>
      <div class="nav-item">📅 ७b. मासिक बैठका व हजेरी</div>
      <div class="sidebar-section">आर्थिक व्यवहार</div>
      <div class="nav-item">📈 ८. उत्पन्न व्यवस्थापन</div>
      <div class="nav-item">📉 ९. खर्च व्यवस्थापन</div>
      <div class="nav-item">📖 १० व १४. बँक व कॅश बुक</div>
      <div class="nav-item">📊 १५. मासिक नफा-तोटा पत्रक</div>
      <div class="nav-item">🤝 १६. वर्गणी व दंड नोंद</div>
      <div class="nav-item">⚠️ २२. थकबाकी व वसुली</div>
      <div class="sidebar-section">अहवाल व प्रशासन</div>
      <div class="nav-item">📑 २४. सर्व अहवाल (Reports)</div>
      <div class="nav-item">⚙️ २६. गट माहिती व नियम</div>
      <div class="nav-item">💾 २७. बॅकअप व रिस्टोअर (.db)</div>
    </div>
    <div class="content-area">
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
        <div class="kpi-card c-blue">
          <div class="lbl">एकूण नोंदणीकृत सदस्य</div>
          <div class="val">२० महिला</div>
          <div class="sub">सर्व सक्रिय (100% KYC पूर्ण)</div>
        </div>
        <div class="kpi-card c-green">
          <div class="lbl">एकूण जमा मासिक बचत</div>
          <div class="val">₹ १,२५,०००.००</div>
          <div class="sub">चालू महिना: ₹ १०,००० जमा</div>
        </div>
        <div class="kpi-card c-orange">
          <div class="lbl">सक्रिय अंतर्गत कर्जे</div>
          <div class="val">₹ ८५,०००.००</div>
          <div class="sub">६ सदस्यांकडे चालू कर्ज</div>
        </div>
        <div class="kpi-card c-red">
          <div class="lbl">थकीत हप्ते व विलंब</div>
          <div class="val">₹ ३,८६६.००</div>
          <div class="sub">२ हप्ते थकीत (स्मरणपत्र पाठवले)</div>
        </div>
      </div>
      <div class="kpi-grid">
        <div class="kpi-card c-purple">
          <div class="lbl">बँक ऑफ महाराष्ट्र शिल्लक</div>
          <div class="val">₹ ४५,०००.००</div>
          <div class="sub">खाते क्र: ...०८९४</div>
        </div>
        <div class="kpi-card c-teal">
          <div class="lbl">पेटीतील हातातील रोख शिल्लक</div>
          <div class="val">₹ ९,१३४.००</div>
          <div class="sub">प्रत्यक्ष रोख जुळणी पूर्ण</div>
        </div>
        <div class="kpi-card c-green">
          <div class="lbl">चालू महिना एकूण उत्पन्न</div>
          <div class="val">₹ २९,३३७.००</div>
          <div class="sub">बचत + हप्ते + व्याज जमा</div>
        </div>
        <div class="kpi-card c-orange">
          <div class="lbl">चालू महिना एकूण खर्च</div>
          <div class="val">₹ २०,६५०.००</div>
          <div class="sub">कर्ज वाटप ₹२० हजार + खर्च</div>
        </div>
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
    </div>
  </div>
</div>
</body></html>"""

with open(r"e:\BachatgatManagement\screenshots\test_dashboard.html", "w", encoding="utf-8") as f:
    f.write(generate_dashboard_html())

print("Created test_dashboard.html")
cmd = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "--headless",
    "--disable-gpu",
    r"--screenshot=e:\BachatgatManagement\screenshots\02_dashboard.png",
    "--window-size=1200,720",
    r"e:\BachatgatManagement\screenshots\test_dashboard.html"
]
subprocess.run(cmd, check=True)
print("Rendered 02_dashboard.png successfully!")
