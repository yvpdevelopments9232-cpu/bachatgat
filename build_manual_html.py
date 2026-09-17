# -*- coding: utf-8 -*-
"""
Script to generate the master customer user manual HTML with all 23 screens.
100% custom-created SVG/HTML/CSS vector mockups - zero user-uploaded images.
"""

import os
import sys

html_content = """<!DOCTYPE html>
<html lang="mr">
<head>
  <meta charset="UTF-8">
  <title>सखी महिला बचत गट व्यवस्थापन प्रणाली - संपूर्ण ग्राहक वापर पुस्तिका व सर्व २३ स्क्रीन्स मार्गदर्शिका</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;500;600;700&family=Poppins:wght@400;500;600;700&display=swap');

    @page {
      size: A4;
      margin: 8mm 10mm;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: 'Noto Sans Devanagari', 'Poppins', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #1e293b;
      background: #f8fafc;
      font-size: 11px;
      line-height: 1.45;
    }

    .container {
      max-width: 920px;
      margin: 0 auto;
      background: #ffffff;
      padding: 16px;
    }

    /* Master Cover / Header Banner */
    .header-banner {
      background: linear-gradient(135deg, #3B0764 0%, #5C1D8D 40%, #7E22CE 100%);
      color: white;
      padding: 22px 20px;
      border-radius: 10px;
      text-align: center;
      margin-bottom: 16px;
      box-shadow: 0 4px 12px rgba(92, 29, 141, 0.2);
    }

    .header-banner h1 {
      font-size: 23px;
      font-weight: 700;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }

    .header-banner h2 {
      font-size: 13.5px;
      font-weight: 500;
      opacity: 0.95;
    }

    .header-banner .pills-row {
      display: flex;
      justify-content: center;
      gap: 10px;
      margin-top: 10px;
      flex-wrap: wrap;
    }

    .badge-pill {
      display: inline-block;
      background: rgba(255, 255, 255, 0.22);
      border: 1px solid rgba(255, 255, 255, 0.45);
      padding: 3px 12px;
      border-radius: 20px;
      font-size: 10px;
      font-weight: 600;
    }

    /* Section Title */
    .section-title {
      font-size: 14px;
      font-weight: 700;
      color: #5C1D8D;
      border-left: 5px solid #5C1D8D;
      padding: 6px 12px;
      margin-top: 18px;
      margin-bottom: 12px;
      background: #faf5ff;
      border-radius: 0 6px 6px 0;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    /* Tables */
    table.guide-table {
      width: 100%;
      border-collapse: collapse;
      margin: 8px 0 14px 0;
      font-size: 10px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      overflow: hidden;
    }

    table.guide-table th {
      background: #5C1D8D;
      color: white;
      padding: 7px 9px;
      text-align: left;
      font-weight: 600;
      font-size: 10px;
    }

    table.guide-table td {
      padding: 6px 9px;
      border-bottom: 1px solid #e2e8f0;
      vertical-align: middle;
      font-size: 10px;
    }

    table.guide-table tr:nth-child(even) {
      background: #f8fafc;
    }

    .btn-tag {
      display: inline-block;
      background: #f3e8ff;
      color: #6b21a8;
      border: 1px solid #d8b4fe;
      padding: 2px 7px;
      border-radius: 4px;
      font-weight: 600;
      font-size: 9.5px;
      white-space: nowrap;
    }

    /* Screen Mockup Box */
    .screen-mockup {
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      overflow: hidden;
      margin: 10px 0 12px 0;
      background: #ffffff;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.05);
      page-break-inside: avoid;
    }

    .mockup-header {
      background: #0f172a;
      color: #f8fafc;
      padding: 5px 12px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 10.5px;
      font-weight: 600;
    }

    .mockup-dots {
      display: flex;
      gap: 5px;
      align-items: center;
    }

    .mockup-dots span {
      width: 8.5px;
      height: 8.5px;
      border-radius: 50%;
      display: inline-block;
    }

    .dot-red { background: #ef4444; }
    .dot-yellow { background: #f59e0b; }
    .dot-green { background: #10b981; }

    .mockup-body {
      padding: 10px 12px;
      background: #f8fafc;
      border-top: 1px solid #e2e8f0;
    }

    /* Mini UI Elements */
    .mini-topbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #ffffff;
      padding: 5px 10px;
      border-radius: 5px;
      border: 1px solid #e2e8f0;
      margin-bottom: 8px;
      font-size: 10px;
    }

    .mini-sidebar-layout {
      display: flex;
      gap: 8px;
    }

    .mini-sidebar {
      width: 175px;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 5px;
      padding: 5px;
      font-size: 9px;
      flex-shrink: 0;
    }

    .mini-sidebar-item {
      padding: 3px 6px;
      border-radius: 4px;
      margin-bottom: 2px;
      color: #475569;
      display: flex;
      align-items: center;
      gap: 5px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .mini-sidebar-item.active {
      background: #5C1D8D;
      color: #ffffff;
      font-weight: 600;
    }

    .mini-content {
      flex: 1;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 5px;
      padding: 8px 10px;
      min-width: 0;
    }

    .mini-kpi-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 5px;
      margin-bottom: 8px;
    }

    .mini-kpi {
      padding: 5px 7px;
      border-radius: 5px;
      color: white;
      font-size: 9px;
    }

    .kpi-blue { background: linear-gradient(135deg, #2563eb, #1d4ed8); }
    .kpi-green { background: linear-gradient(135deg, #10b981, #059669); }
    .kpi-orange { background: linear-gradient(135deg, #f97316, #ea580c); }
    .kpi-red { background: linear-gradient(135deg, #ef4444, #dc2626); }
    .kpi-purple { background: linear-gradient(135deg, #8b5cf6, #7c3aed); }
    .kpi-teal { background: linear-gradient(135deg, #06b6d4, #0891b2); }

    .mini-kpi .title { opacity: 0.9; font-size: 8px; }
    .mini-kpi .val { font-size: 11px; font-weight: 700; margin-top: 1px; }

    .mini-form-card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 5px;
      padding: 8px;
      margin-bottom: 8px;
    }

    .mini-form-row {
      display: flex;
      gap: 6px;
      margin-bottom: 6px;
      align-items: center;
    }

    .mini-input-box {
      flex: 1;
      border: 1px solid #cbd5e1;
      border-radius: 4px;
      padding: 4px 6px;
      background: #ffffff;
      font-size: 9px;
    }

    .mini-input-label {
      font-size: 7.5px;
      color: #64748b;
      margin-bottom: 1px;
      text-transform: uppercase;
      font-weight: 600;
    }

    .mini-btn {
      background: #5C1D8D;
      color: white;
      border: none;
      padding: 4px 10px;
      border-radius: 4px;
      font-weight: 600;
      font-size: 9px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      cursor: pointer;
    }

    .mini-btn-green { background: #10b981; }
    .mini-btn-blue { background: #2563eb; }
    .mini-btn-amber { background: #f59e0b; }
    .mini-btn-red { background: #ef4444; }

    .mini-badge {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 8px;
      font-weight: 600;
    }

    .badge-success { background: #dcfce7; color: #15803d; }
    .badge-warning { background: #fef3c7; color: #b45309; }
    .badge-danger { background: #fee2e2; color: #b91c1c; }
    .badge-info { background: #e0f2fe; color: #0369a1; }
    .badge-purple { background: #f3e8ff; color: #7e22ce; }

    .step-desc {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-left: 4px solid #5C1D8D;
      border-radius: 0 5px 5px 0;
      padding: 8px 12px;
      margin-bottom: 14px;
      font-size: 10px;
      page-break-inside: avoid;
    }

    .step-desc ol {
      margin-left: 16px;
      margin-top: 4px;
    }

    .step-desc li {
      margin-bottom: 3px;
      color: #334155;
    }

    .page-break {
      page-break-after: always;
    }

    .footer-note {
      text-align: center;
      font-size: 9px;
      color: #94a3b8;
      border-top: 1px solid #e2e8f0;
      padding-top: 8px;
      margin-top: 16px;
    }

    .tabs-bar {
      display: flex;
      gap: 4px;
      border-bottom: 1.5px solid #e2e8f0;
      margin-bottom: 8px;
    }

    .tab-item {
      padding: 4px 10px;
      font-size: 9.5px;
      font-weight: 600;
      color: #64748b;
      border-bottom: 2px solid transparent;
    }

    .tab-item.active {
      color: #5C1D8D;
      border-bottom-color: #5C1D8D;
    }
  </style>
</head>
<body>

<div class="container">

  <!-- MASTER COVER / HEADER -->
  <div class="header-banner">
    <h1>सखी महिला बचत गट व्यवस्थापन प्रणाली</h1>
    <h2>अधिकृत ग्राहक वापर पुस्तिका व सर्व २३ स्क्रीन्स सचित्र मार्गदर्शिका</h2>
    <div class="pills-row">
      <span class="badge-pill">संस्करण २.० (२०२६ अधिकृत आवृत्ती)</span>
      <span class="badge-pill">Windows & Android सपोर्ट</span>
      <span class="badge-pill">ऑफलाइन / ऑनलाइन / हायब्रिड आवृत्ती</span>
      <span class="badge-pill">१००% डेटा सुरक्षा व स्थानिक बॅकअप (.db)</span>
    </div>
  </div>

  <!-- भाग १: REQUIREMENT TO MODULE TABLE -->
  <div class="section-title">
    <span>भाग १: गरजेनुसार डाव्या मेनू बारवरील पर्याय जलद संदर्भ (Requirement-to-Module Master Table)</span>
    <span style="font-size: 9.5px; font-weight: normal; color: #6b21a8;">माझी गरज &rarr; मेनू बार बटण &rarr; कृती</span>
  </div>

  <table class="guide-table">
    <thead>
      <tr>
        <th style="width: 24%;">तुमची गरज / काय काम करायचे आहे?</th>
        <th style="width: 28%;">डाव्या मेनू बारवरील पर्याय (Module)</th>
        <th style="width: 48%;">थोडक्यात कृती (Step-by-step Action)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>१. लॉगिन / पिन बदलणे</strong></td>
        <td><span class="btn-tag">१. लॉगिन व ऑथेंटिकेशन</span></td>
        <td>मोबाईल नंबर व पासवर्ड टाका. ऑफलाइनसाठी डीफॉल्ट पिन <code>1234</code> वापरून त्वरित लॉगिन करा.</td>
      </tr>
      <tr>
        <td><strong>२. गटाचा संपूर्ण आढावा पाहणे</strong></td>
        <td><span class="btn-tag">३. मुख्य डॅशबोर्ड</span></td>
        <td>एकूण बचत, शिल्लक रोख, बँक जमा, सक्रिय कर्जे, थकीत हप्ते व उत्पन्न-खर्च एकाच दृष्टिक्षेपात पहा.</td>
      </tr>
      <tr>
        <td><strong>३. नवीन सदस्य जोडणे / KYC</strong></td>
        <td><span class="btn-tag">४. सदस्य व्यवस्थापन</span></td>
        <td><strong>+ नवीन सदस्य जोडा</strong> वर दाबा &rarr; नाव, पत्ता, मोबाईल, बँक खाते, आधार व वारसदार नोंदवून जतन करा.</td>
      </tr>
      <tr>
        <td><strong>४. मासिक बचत जमा करणे</strong></td>
        <td><span class="btn-tag">५. मासिक बचत नोंद</span></td>
        <td>सदस्य निवडा &rarr; बचत रक्कम (उदा. ₹२००/₹५००) भरा &rarr; भरणा माध्यम (रोख/UPI) निवडा &rarr; बचत पावती द्या.</td>
      </tr>
      <tr>
        <td><strong>५. अंतर्गत कर्ज मंजूर करणे</strong></td>
        <td><span class="btn-tag">६. कर्ज वाटप (Loan Disburse)</span></td>
        <td><strong>नवीन कर्ज वाटप</strong> वर दाबा &rarr; सदस्य, रक्कम (₹२०,०००), मुदत, २ जामीनदार निवडून कर्ज मंजूर करा.</td>
      </tr>
      <tr>
        <td><strong>६. कर्जाचा मासिक हप्ता भरणे</strong></td>
        <td><span class="btn-tag">७. हप्ता वसुली (Collect EMI)</span></td>
        <td>कर्ज यादीत सदस्यासमोरील <strong>हप्ता भरा</strong> दाबा &rarr; मुद्दल व व्याज तपासा &rarr; पावती सेव्ह व प्रिंट करा.</td>
      </tr>
      <tr>
        <td><strong>७. मासिक बैठक व हजेरी नोंद</strong></td>
        <td><span class="btn-tag">७b. मासिक बैठका व हजेरी</span></td>
        <td><strong>नवीन बैठक</strong> तयार करा &rarr; तारीख व विषयसूची भरा &rarr; <strong>हजेरी</strong> टॅबमध्ये उपस्थित/गैरहजर नोंदवा.</td>
      </tr>
      <tr>
        <td><strong>८. गटाचे उत्पन्न नोंदवणे</strong></td>
        <td><span class="btn-tag">८. उत्पन्न व्यवस्थापन</span></td>
        <td><strong>उत्पन्न नोंदवा</strong> दाबा &rarr; विक्री, बँक व्याज, शासकीय अनुदान निवडून पावती नंबर व रक्कम सेव्ह करा.</td>
      </tr>
      <tr>
        <td><strong>९. गटाचा खर्च नोंदवणे</strong></td>
        <td><span class="btn-tag">९. खर्च व्यवस्थापन</span></td>
        <td><strong>खर्च व्हाउचर</strong> तयार करा &rarr; स्टेशनरी, चहापान, प्रवास निवडून बिल रक्कम व तपशील भरा.</td>
      </tr>
      <tr>
        <td><strong>१०. रोख व बँक शिल्लक तपासणे</strong></td>
        <td><span class="btn-tag">१० व १४. बँक व कॅश बुक</span></td>
        <td>हातातील रोख शिल्लक (Cash in Hand) आणि बँक खात्यातील शिल्लक तपासा; रोजचे जमा-खर्च क्रमाने पहा.</td>
      </tr>
      <tr>
        <td><strong>११. उत्पादने स्टॉक व विक्री</strong></td>
        <td><span class="btn-tag">११ व १२. उत्पादने व स्टॉक POS</span></td>
        <td>पापड, लोणचे, मसाले स्टॉक नोंदवा &rarr; <strong>विक्री नोंदवा (POS)</strong> वरून ग्राहकास बिल पावती द्या.</td>
      </tr>
      <tr>
        <td><strong>१२. बँकेचे कर्ज व शासकीय योजना</strong></td>
        <td><span class="btn-tag">१३ व १७. बँक कर्ज व योजना</span></td>
        <td>उमेद/NRLM किंवा बँकेकडून मिळालेले कर्ज खाते नोंदवा, मुदत व बँक हप्ता परतफेड ट्रॅक करा.</td>
      </tr>
      <tr>
        <td><strong>१३. मासिक नफा-तोटा तपासणे</strong></td>
        <td><span class="btn-tag">१५. नफा-तोटा पत्रक</span></td>
        <td>चालू महिन्याची सर्व जमा vs सर्व खर्च निव्वळ नफा (Net Surplus) पत्रक तपासा.</td>
      </tr>
      <tr>
        <td><strong>१४. वर्गणी किंवा दंड आकारणे</strong></td>
        <td><span class="btn-tag">१६. वर्गणी व दंड नोंद</span></td>
        <td>बैठक गैरहजर दंड (₹५०), उशीर दंड किंवा वार्षिक उत्सव वर्गणी सदस्याच्या नावावर नोंदवून वसूल करा.</td>
      </tr>
      <tr>
        <td><strong>१५. बैठकीचे ठराव व कागदपत्रे</strong></td>
        <td><span class="btn-tag">१८. ठराव वही व KYC</span></td>
        <td>बैठकीत मंजूर ठराव क्रमांक व इतिवृत्त लिहा; सदस्यांचे आधार/पॅन/बँक पासबुक कागदपत्रे जोडा.</td>
      </tr>
      <tr>
        <td><strong>१६. महिला प्रशिक्षण व मेळावा</strong></td>
        <td><span class="btn-tag">२० व २१. प्रशिक्षण व उपक्रम</span></td>
        <td>कौशल्य प्रशिक्षण शिबिरे, बचत गट प्रदर्शन व मेळावा उपक्रमांची माहिती व खर्च नोंदवा.</td>
      </tr>
      <tr>
        <td><strong>१७. थकबाकी पाहणे व तगादा लावणे</strong></td>
        <td><span class="btn-tag">२२. थकबाकी व वसुली</span></td>
        <td>कोणाकडे किती बचत किंवा हप्ता बाकी आहे ते पहा &rarr; सदस्याला <strong>WhatsApp / SMS स्मरणपत्र</strong> पाठवा.</td>
      </tr>
      <tr>
        <td><strong>१८. सूचना व देय स्मरणपत्रे</strong></td>
        <td><span class="btn-tag">२३. सूचना व स्मरणपत्रे</span></td>
        <td>कर्ज हप्ता तारीख, आगामी बैठकीचे स्मरणपत्र व सिंक इशारे एकाच जागी पहा.</td>
      </tr>
      <tr>
        <td><strong>१९. ३८+ शासकीय अहवाल PDF</strong></td>
        <td><span class="btn-tag">२४. सर्व अहवाल (Reports)</span></td>
        <td>मासिक अहवाल, वार्षिक ताळेबंद, वैयक्तिक पासबुक, वसुली तक्ता निवडून <strong>PDF डाऊनलोड करा</strong>.</td>
      </tr>
      <tr>
        <td><strong>२०. ऑडिट व बदल ट्रॅकिंग</strong></td>
        <td><span class="btn-tag">२५. ऑडिट व हालचाली नोंद</span></td>
        <td>कोणत्या कार्यकर्तीने कधी कोणती नोंद केली किंवा बदलली याचा पूर्ण ऑडिट ट्रेल (Audit Log) तपासा.</td>
      </tr>
      <tr>
        <td><strong>२१. गट नियम व पदाधिकारी बदल</strong></td>
        <td><span class="btn-tag">२६. गट माहिती, फोटो व नियम</span></td>
        <td>गटाचा लोगो, अध्यक्षा, सचिवा, खजिनदार यांचे नाव व मोबाईल, मासिक बचत नियम अद्ययावत करा.</td>
      </tr>
      <tr>
        <td><strong>२२. संपूर्ण डेटा बॅकअप घेणे (.db)</strong></td>
        <td><span class="btn-tag">२७. बॅकअप व रिस्टोअर (.db)</span></td>
        <td><strong>बॅकअप एक्सपोर्ट (Export)</strong> दाबा &rarr; <code>.db</code> फाईल पेनड्राइव्ह किंवा फोनमध्ये सुरक्षित सेव्ह करा.</td>
      </tr>
      <tr>
        <td><strong>२३. मोबाईलवर स्क्रीन झूम करणे</strong></td>
        <td><span class="btn-tag">मोबाईल व्ह्यू व झूम टूलबार</span></td>
        <td>दोन बोटांनी पिंच-झूम करा किंवा खालील <strong>झूम टूलबार</strong> वरील <code>+</code>, <code>-</code>, <code>Fit</code> वापरा.</td>
      </tr>
    </tbody>
  </table>

  <div class="page-break"></div>

  <!-- भाग २: सर्व २३ स्क्रीन्स सचित्र मार्गदर्शिका -->
  <div class="section-title">
    <span>भाग २: सर्व २३ स्क्रीन्सचे थेट दृश्य व सविस्तर कार्यपद्धती (All 23 Visual Screens Guide)</span>
    <span style="font-size: 9.5px; font-weight: normal; color: #6b21a8;">प्रत्येक स्क्रीनचे चित्र व पायऱ्या</span>
  </div>

  <!-- SCREEN 1: LOGIN -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १: लॉगिन व ऑथेंटिकेशन (Login & PIN Authentication)</span>
      <span class="mini-badge badge-success">सुरक्षित प्रवेशद्वार</span>
    </div>
    <div class="mockup-body" style="text-align: center; padding: 16px;">
      <div style="max-width: 320px; margin: 0 auto; background: white; padding: 16px; border-radius: 8px; border: 1px solid #e2e8f0; box-shadow: 0 2px 6px rgba(0,0,0,0.05);">
        <div style="width: 44px; height: 44px; background: #5C1D8D; border-radius: 50%; color: white; display: flex; align-items: center; justify-content: center; margin: 0 auto 6px auto; font-size: 20px;">👥</div>
        <div style="font-weight: 700; color: #5C1D8D; font-size: 14px;">सखी महिला बचत गट</div>
        <div style="font-size: 9.5px; color: #64748b; margin-bottom: 10px;">महिला सक्षमीकरण व आर्थिक व्यवस्थापन प्रणाली</div>
        <div class="mini-input-box" style="text-align: left; margin-bottom: 6px;">
          <div class="mini-input-label">वापरकर्ता ईमेल किंवा मोबाईल नंबर</div>
          <div>admin@bachatgat.org</div>
        </div>
        <div class="mini-input-box" style="text-align: left; margin-bottom: 10px;">
          <div class="mini-input-label">पासवर्ड किंवा ४-अंकी सुरक्षा पिन</div>
          <div>••••••••</div>
        </div>
        <button class="mini-btn" style="width: 100%; justify-content: center; padding: 6px; margin-bottom: 6px;">लॉगिन करा (Login)</button>
        <div style="font-size: 9px; color: #64748b;">नवीन बचत गट नोंदणी? <strong style="color: #5C1D8D;">Sign Up करा</strong> | डीफॉल्ट ऑफलाइन पिन: <strong>1234</strong></div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong>
    <ol>
      <li>नोंदणीकृत मोबाईल नंबर किंवा ईमेल आणि पासवर्ड टाका.</li>
      <li><strong>लॉगिन करा</strong> बटणावर क्लिक करा. ऑफलाइन आवृत्तीमध्ये इंटरनेट नसतानाही डीफॉल्ट पिन <code>1234</code> वापरून त्वरित लॉगिन होते.</li>
    </ol>
  </div>

  <!-- SCREEN 2: MAIN DASHBOARD -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन २: मुख्य डॅशबोर्ड व डावा मेनू बार (Module 3: Main Dashboard & Vertical Bar)</span>
      <span class="mini-badge badge-success">Live Synced</span>
    </div>
    <div class="mockup-body">
      <div class="mini-topbar">
        <div><strong>सावित्रीबाई फुले महिला बचत गट</strong> <span style="font-size: 9.5px; color: #64748b;">• पंढरपूर, सोलापूर</span></div>
        <div style="display: flex; gap: 6px; align-items: center;">
          <span class="mini-badge badge-success">सिंक पूर्ण ✓</span>
          <span style="font-size: 9.5px;">👤 अध्यक्षा: सुनंदा मारुती पवार</span>
        </div>
      </div>
      <div class="mini-sidebar-layout">
        <div class="mini-sidebar">
          <div class="mini-sidebar-item active">📊 ३. मुख्य डॅशबोर्ड</div>
          <div class="mini-sidebar-item">👥 ४. सदस्य व्यवस्थापन</div>
          <div class="mini-sidebar-item">💰 ५. मासिक बचत नोंद</div>
          <div class="mini-sidebar-item">💳 ६ व ७. कर्ज व हप्ता वसुली</div>
          <div class="mini-sidebar-item">📅 ७b. मासिक बैठका व हजेरी</div>
          <div class="mini-sidebar-item">📈 ८. उत्पन्न व्यवस्थापन</div>
          <div class="mini-sidebar-item">📉 ९. खर्च व्यवस्थापन</div>
          <div class="mini-sidebar-item">📖 १०. रोख वही व बँक</div>
          <div class="mini-sidebar-item">📑 २४. सर्व अहवाल (Reports)</div>
          <div class="mini-sidebar-item">💾 २७. बॅकअप व रिस्टोअर</div>
        </div>
        <div class="mini-content">
          <div class="mini-kpi-grid">
            <div class="mini-kpi kpi-blue"><div class="title">एकूण सदस्य</div><div class="val">२० महिला</div></div>
            <div class="mini-kpi kpi-green"><div class="title">एकूण बचत</div><div class="val">₹ १,२५,०००</div></div>
            <div class="mini-kpi kpi-orange"><div class="title">सक्रिय अंतर्गत कर्ज</div><div class="val">₹ ८५,०००</div></div>
            <div class="mini-kpi kpi-red"><div class="title">थकीत हप्ते</div><div class="val">२ हप्ते (₹ ३,८६६)</div></div>
          </div>
          <div class="mini-kpi-grid">
            <div class="mini-kpi kpi-purple"><div class="title">बँक शिल्लक</div><div class="val">₹ ४५,०००</div></div>
            <div class="mini-kpi kpi-teal"><div class="title">हातातील रोख</div><div class="val">₹ ९,१३४</div></div>
            <div class="mini-kpi kpi-green"><div class="title">चालू महिना जमा</div><div class="val">₹ २९,३३७</div></div>
            <div class="mini-kpi kpi-orange"><div class="title">चालू महिना खर्च</div><div class="val">₹ २०,४००</div></div>
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> ॲप उघडताच मुख्य डॅशबोर्ड दिसतो. डाव्या बाजूच्या मेनू बारवरील कोणत्याही पर्यायावर क्लिक करून थेट त्या विभागात जाता येते. कार्ड्सवर क्लिक केल्यास थेट तपशील उघडतो.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 3: MEMBER MANAGEMENT -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ३: सदस्य व्यवस्थापन व प्रोफाइल (Module 4: Members & Profile)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ नवीन सदस्य जोडा</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>कोड</th>
            <th>सदस्याचे पूर्ण नाव</th>
            <th>मोबाईल नंबर</th>
            <th>पद</th>
            <th>वारसदार</th>
            <th>एकूण बचत</th>
            <th>कर्ज बाकी</th>
            <th>स्थिती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>MBG-001</strong></td>
            <td>सुनंदा मारुती पवार</td>
            <td>9876543210</td>
            <td><span class="mini-badge badge-purple">अध्यक्षा</span></td>
            <td>मारुती पवार (पती)</td>
            <td>₹ ६,०००</td>
            <td>₹ ०</td>
            <td><span class="mini-badge badge-success">सक्रिय</span></td>
          </tr>
          <tr>
            <td><strong>MBG-002</strong></td>
            <td>मीना अशोक जाधव</td>
            <td>9765432109</td>
            <td><span class="mini-badge badge-info">सचिवा</span></td>
            <td>अशोक जाधव (पती)</td>
            <td>₹ ६,०००</td>
            <td>₹ १५,०००</td>
            <td><span class="mini-badge badge-success">सक्रिय</span></td>
          </tr>
          <tr>
            <td><strong>MBG-003</strong></td>
            <td>कविता बापू शिंदे</td>
            <td>9654321098</td>
            <td><span class="mini-badge badge-warning">खजिनदार</span></td>
            <td>बापू शिंदे (पती)</td>
            <td>₹ ६,०००</td>
            <td>₹ ०</td>
            <td><span class="mini-badge badge-success">सक्रिय</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong>
    <ol>
      <li>डाव्या मेनूवरील <strong>४. सदस्य व्यवस्थापन</strong> दाबा.</li>
      <li>नवीन सदस्यासाठी उजवीकडील <strong>+ नवीन सदस्य जोडा</strong> दाबा. नाव, पत्ता, मोबाईल, बँक खाते, आधार व वारसदार माहिती भरून सेव्ह करा.</li>
      <li>सदस्याच्या नावावर क्लिक केल्यास त्यांचे वैयक्तिक पासबुक व संपूर्ण इतिहास उघडतो.</li>
    </ol>
  </div>

  <!-- SCREEN 4: MONTHLY SAVINGS COLLECTION -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ४: मासिक बचत नोंद व खातेवही (Module 5: Monthly Savings Collection)</span>
      <span class="mini-badge badge-success">दरमहा बचत संकलन</span>
    </div>
    <div class="mockup-body">
      <div class="mini-form-card">
        <div style="font-weight: 700; color: #5C1D8D; margin-bottom: 6px;">मासिक बचत संकलन फॉर्म (सप्टेंबर २०२६)</div>
        <div class="mini-form-row">
          <div class="mini-input-box" style="flex: 2;">
            <div class="mini-input-label">सभासद निवडा *</div>
            <div>मीना अशोक जाधव (MBG-002)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">बचत रक्कम (₹) *</div>
            <div style="font-weight: 700; color: #15803d;">₹ ५००.००</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">भरणा माध्यम *</div>
            <div>रोख (Cash) / UPI</div>
          </div>
          <button class="mini-btn mini-btn-green">बचत जमा करा ✓</button>
        </div>
      </div>
      <div style="background: white; border: 1px dashed #5C1D8D; padding: 6px 10px; border-radius: 5px; display: flex; justify-content: space-between; align-items: center;">
        <div><strong>पावती:</strong> SAV-2026-09-002 | <strong>सदस्य:</strong> मीना अशोक जाधव | <strong>रक्कम:</strong> ₹ ५०० (रोख)</div>
        <button class="mini-btn mini-btn-blue" style="font-size: 8.5px; padding: 2px 6px;">प्रिंट पावती 🖨️</button>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>५. मासिक बचत नोंद</strong> दाबा. सभासद निवडून बचत रक्कम तपासा व <strong>बचत जमा करा</strong> दाबा. त्वरित डिजिटल पावती तयार होते.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 5: INTERNAL LOAN DISBURSAL -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ५: अंतर्गत कर्ज वाटप व EMI गणकयंत्र (Module 6: Internal Loan Disbursal)</span>
      <span class="mini-badge badge-warning">नवीन कर्ज मंजुरी</span>
    </div>
    <div class="mockup-body">
      <div class="mini-form-card" style="background: #faf5ff; border-color: #d8b4fe;">
        <div style="font-weight: 700; color: #5C1D8D; margin-bottom: 6px;">नवीन अंतर्गत कर्ज वाटप संवाद (Loan Disburse Dialog)</div>
        <div class="mini-form-row">
          <div class="mini-input-box" style="flex: 2;">
            <div class="mini-input-label">कर्जदार सभासद</div>
            <div>मीना अशोक जाधव (MBG-002)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">कर्ज रक्कम (₹)</div>
            <div style="font-weight: 700; color: #5C1D8D;">₹ २०,०००</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">व्याज दर</div>
            <div>२% दरमहा (२४% वार्षिक)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">मुदत</div>
            <div>१२ महिने</div>
          </div>
        </div>
        <div class="mini-form-row">
          <div class="mini-input-box">
            <div class="mini-input-label">जामीनदार १</div>
            <div>सुनंदा पवार (MBG-001)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">जामीनदार २</div>
            <div>कविता शिंदे (MBG-003)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">कर्जाचा हेतू</div>
            <div>किराणा दुकान व्यवसाय</div>
          </div>
        </div>
        <div style="background: white; border: 1px solid #e2e8f0; padding: 6px; border-radius: 5px; margin: 6px 0; display: flex; justify-content: space-around; font-size: 10px;">
          <div>दरमहा मुद्दल: <strong>₹ १,६६७</strong></div>
          <div>दरमहा व्याज: <strong>₹ ४००</strong></div>
          <div>मासिक हप्ता (EMI): <strong style="color: #5C1D8D; font-size: 11px;">₹ २,०६७</strong></div>
          <div>एकूण परतफेड: <strong>₹ २४,८०४</strong></div>
        </div>
        <div style="text-align: right;">
          <button class="mini-btn mini-btn-green">कर्ज मंजूर करा व पावती द्या ✓</button>
        </div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>६ व ७. कर्ज वाटप</strong> दाबा &rarr; <strong>नवीन कर्ज वाटप</strong> दाबा &rarr; कर्जदार, रक्कम, मुदत व २ जामीनदार निवडून सेव्ह करा. EMI स्वयंचलित गणली जाते.
  </div>

  <!-- SCREEN 6: COLLECT EMI & REPAYMENT -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ६: कर्ज हप्ता वसुली व परतफेड नोंद (Module 7: Collect EMI & Repayments)</span>
      <span class="mini-badge badge-success">EMI संकलन</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>कर्ज कोड</th>
            <th>कर्जदार नाव</th>
            <th>एकूण कर्ज</th>
            <th>शिल्लक मुद्दल</th>
            <th>हप्ता क्र.</th>
            <th>मासिक मुद्दल</th>
            <th>मासिक व्याज</th>
            <th>कृती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>LN-2026-001</strong></td>
            <td>मीना अशोक जाधव</td>
            <td>₹ २०,०००</td>
            <td>₹ १८,३३३</td>
            <td>२ / १२</td>
            <td>₹ १,६६७</td>
            <td>₹ ३६७</td>
            <td><button class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">हप्ता भरा (Collect)</button></td>
          </tr>
          <tr>
            <td><strong>LN-2026-002</strong></td>
            <td>लता संभाजी मोरे</td>
            <td>₹ १५,०००</td>
            <td>₹ १०,०००</td>
            <td>५ / १२</td>
            <td>₹ १,२५०</td>
            <td>₹ २००</td>
            <td><button class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">हप्ता भरा (Collect)</button></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> सक्रिय कर्जांच्या यादीत सदस्यासमोरील <strong>हप्ता भरा</strong> बटणावर क्लिक करा. मुद्दल आणि व्याज स्वयंचलित विभागले जाते. जमा बटण दाबताच हिशोब अद्ययावत होतो.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 7: MEETINGS & ATTENDANCE -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ७: मासिक बैठका व हजेरी नोंदवही (Module 7b: Meetings & Attendance Register)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ नवीन बैठक आयोजित करा</span>
    </div>
    <div class="mockup-body">
      <div class="mini-topbar" style="margin-bottom: 6px;">
        <div><strong>बैठक क्र. २४:</strong> सप्टेंबर २०२६ मासिक सभा | <strong>तारीख:</strong> १०-०९-२०२६ | <strong>स्थान:</strong> समाज मंदिर</div>
        <span class="mini-badge badge-success">पूर्ण झाली (Completed)</span>
      </div>
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>अ.क्र.</th>
            <th>सदस्याचे नाव</th>
            <th>पद</th>
            <th>हजेरी स्थिती</th>
            <th>बचत जमा?</th>
            <th>दंड आकारणी</th>
            <th>स्वाक्षरी / शेरा</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>१</td>
            <td>सुनंदा मारुती पवार</td>
            <td>अध्यक्षा</td>
            <td><span class="mini-badge badge-success">हजर (Present)</span></td>
            <td>होय (₹ ५००)</td>
            <td>₹ ०</td>
            <td>उपस्थित</td>
          </tr>
          <tr>
            <td>२</td>
            <td>मीना अशोक जाधव</td>
            <td>सचिवा</td>
            <td><span class="mini-badge badge-success">हजर (Present)</span></td>
            <td>होय (₹ ५००)</td>
            <td>₹ ०</td>
            <td>उपस्थित</td>
          </tr>
          <tr>
            <td>३</td>
            <td>छाया दीपक कांबळे</td>
            <td>सदस्य</td>
            <td><span class="mini-badge badge-danger">गैरहजर (Absent)</span></td>
            <td>नाही</td>
            <td><span class="mini-badge badge-warning">₹ ५० दंड</span></td>
            <td>पूर्वपरवानगी नाही</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>७b. मासिक बैठका</strong> दाबा. बैठकीची तारीख व अजेंडा नोंदवून सदस्यांची हजेरी नोंदवा. गैरहजर सदस्यांवर एका क्लिकवर आपोआप दंड आकारला जातो.
  </div>

  <!-- SCREEN 8: INCOME MANAGEMENT -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ८: उत्पन्न व्यवस्थापन व पावती नोंद (Module 8: Income Management)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ उत्पन्न नोंदवा</span>
    </div>
    <div class="mockup-body">
      <div class="tabs-bar">
        <div class="tab-item active">उत्पन्न यादी (Income List)</div>
        <div class="tab-item">+ नवीन उत्पन्न नोंद फॉर्म</div>
      </div>
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>पावती क्र.</th>
            <th>तारीख</th>
            <th>उत्पन्नाचा प्रकार (वर्गवारी)</th>
            <th>कोणाकडून मिळाले</th>
            <th>माध्यम</th>
            <th>रक्कम (₹)</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>INC-2026-001</td>
            <td>०५-०९-२०२६</td>
            <td>कर्ज व्याज (Loan Interest)</td>
            <td>सदस्य कर्ज परतफेड</td>
            <td>बँक जमा</td>
            <td><strong>₹ २,६७०.००</strong></td>
          </tr>
          <tr>
            <td>INC-2026-002</td>
            <td>०६-०९-२०२६</td>
            <td>उत्पादने विक्री (Product Sales)</td>
            <td>गणेशोत्सव स्टॉल विक्री</td>
            <td>रोख (Cash)</td>
            <td><strong>₹ ८,५००.००</strong></td>
          </tr>
          <tr>
            <td>INC-2026-003</td>
            <td>०८-०९-२०२६</td>
            <td>शासकीय अनुदान (Govt Grant)</td>
            <td>उमेद अभियान फिरता निधी</td>
            <td>बँक ट्रान्सफर</td>
            <td><strong>₹ १५,०००.००</strong></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>८. उत्पन्न व्यवस्थापन</strong> दाबा. <strong>उत्पन्न नोंदवा</strong> फॉर्म उघडून प्रकार (व्याज, विक्री, अनुदान), रक्कम व तपशील भरून सेव्ह करा.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 9: EXPENSE MANAGEMENT -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ९: खर्च व्यवस्थापन व व्हाउचर्स (Module 9: Expense Management)</span>
      <span class="mini-btn mini-btn-amber" style="font-size: 8.5px; padding: 2px 6px;">+ खर्च व्हाउचर तयार करा</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>व्हाउचर क्र.</th>
            <th>तारीख</th>
            <th>खर्चाचा प्रकार (वर्गवारी)</th>
            <th>देयक व्यक्ती / संस्था</th>
            <th>माध्यम</th>
            <th>रक्कम (₹)</th>
            <th>स्थिती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>EXP-2026-001</td>
            <td>०२-०९-२०२६</td>
            <td>स्टेशनरी व दप्तर नोंदवह्या</td>
            <td>गुरुदत्त स्टेशनर्स</td>
            <td>रोख</td>
            <td>₹ ३५०.००</td>
            <td><span class="mini-badge badge-success">मंजूर</span></td>
          </tr>
          <tr>
            <td>EXP-2026-002</td>
            <td>०५-०९-२०२६</td>
            <td>बैठक चहापान व अल्पोपहार</td>
            <td>आनंद टी स्टॉल</td>
            <td>रोख</td>
            <td>₹ २५०.००</td>
            <td><span class="mini-badge badge-success">मंजूर</span></td>
          </tr>
          <tr>
            <td>EXP-2026-003</td>
            <td>०९-०९-२०२६</td>
            <td>बँक शुल्क व पासबुक एंट्री</td>
            <td>बँक ऑफ महाराष्ट्र</td>
            <td>बँक डेबिट</td>
            <td>₹ ५०.००</td>
            <td><span class="mini-badge badge-success">मंजूर</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>९. खर्च व्यवस्थापन</strong> दाबा. <strong>+ खर्च व्हाउचर</strong> दाबा &rarr; खर्चाचे कारण, बिल नंबर व रक्कम नोंदवून जतन करा. खर्च रोख वहीत आपोआप नोंदवला जातो.
  </div>

  <!-- SCREEN 10: BANK & CASH BOOK -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १०: बँक खाती व रोख वही (Module 10 & 14: Bank Accounts & Cash Book)</span>
      <span class="mini-badge badge-success">दैनिक रोख ताळेबंद</span>
    </div>
    <div class="mockup-body">
      <div class="mini-kpi-grid" style="margin-bottom: 6px;">
        <div class="mini-kpi kpi-teal"><div class="title">हातातील रोख शिल्लक</div><div class="val">₹ ९,१३४.००</div></div>
        <div class="mini-kpi kpi-purple"><div class="title">बँक ऑफ महाराष्ट्र शिल्लक</div><div class="val">₹ ४५,०००.००</div></div>
        <div class="mini-kpi kpi-green"><div class="title">एकूण जमा (Receipts)</div><div class="val">₹ २९,३३७.००</div></div>
        <div class="mini-kpi kpi-orange"><div class="title">एकूण खर्च (Payments)</div><div class="val">₹ २०,६५०.००</div></div>
      </div>
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>तारीख</th>
            <th>पावती / व्हाउचर</th>
            <th>तपशील (Particulars)</th>
            <th>खाते प्रकार</th>
            <th>जमा (₹ Cr)</th>
            <th>खर्च (₹ Dr)</th>
            <th>शिल्लक (₹)</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>०१-०९-२०२६</td>
            <td>OB-001</td>
            <td>मागील महिन्याची शिल्लक (Opening)</td>
            <td>रोख / बँक</td>
            <td>₹ ४५,४४७.००</td>
            <td>-</td>
            <td>₹ ४५,४४७.००</td>
          </tr>
          <tr>
            <td>०५-०९-२०२६</td>
            <td>SAV-2026-09</td>
            <td>मासिक बचत संकलन (२० सदस्य)</td>
            <td>रोख</td>
            <td>₹ १०,०००.००</td>
            <td>-</td>
            <td>₹ ५५,४४७.००</td>
          </tr>
          <tr>
            <td>०५-०९-२०२६</td>
            <td>LN-DISB-01</td>
            <td>मीना जाधव यांना अंतर्गत कर्ज वाटप</td>
            <td>बँक ट्रान्सफर</td>
            <td>-</td>
            <td>₹ २०,०००.००</td>
            <td>₹ ३५,४४७.००</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>१० व १४. बँक व कॅश बुक</strong> दाबा. प्रत्येक व्यवहाराची पावती, जमा रक्कम, नावे खर्च आणि चालू शिल्लक एकाच दृष्टीक्षेपात दिसते.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 11: PRODUCTS & INVENTORY POS -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन ११: उत्पादने व स्टॉक POS (Module 11 & 12: Products & Inventory POS)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ नवीन उत्पादन जोडा</span>
    </div>
    <div class="mockup-body">
      <div class="mini-topbar" style="margin-bottom: 6px;">
        <div><strong>गटाचे लघुउद्योग उत्पादने:</strong> पापड, लोणचे, मसाले व शेवया निर्मिती केंद्र</div>
        <button class="mini-btn mini-btn-blue" style="font-size: 8.5px; padding: 2px 6px;">विक्री बिल नोंदवा (POS) 🛒</button>
      </div>
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>उत्पादन नाव</th>
            <th>वर्गवारी</th>
            <th>पॅकिंग एकक</th>
            <th>खरेदी किंमत</th>
            <th>विक्री दर (₹)</th>
            <th>उपलब्ध स्टॉक</th>
            <th>स्थिती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>उडीद पापड (स्पेशल)</strong></td>
            <td>खाद्यपदार्थ</td>
            <td>५०० ग्रॅम पॅकेट</td>
            <td>₹ ११०.००</td>
            <td>₹ १४०.००</td>
            <td><strong>८५ पॅकेट</strong></td>
            <td><span class="mini-badge badge-success">स्टॉकमध्ये</span></td>
          </tr>
          <tr>
            <td><strong>गावरान कैरी लोणचे</strong></td>
            <td>खाद्यपदार्थ</td>
            <td>१ किलो बरणी</td>
            <td>₹ १८०.००</td>
            <td>₹ २५०.००</td>
            <td><strong>४२ बरण्या</strong></td>
            <td><span class="mini-badge badge-success">स्टॉकमध्ये</span></td>
          </tr>
          <tr>
            <td><strong>सुगंधी अगरबत्ती</strong></td>
            <td>गृहउपयोगी</td>
            <td>२५० ग्रॅम बॉक्स</td>
            <td>₹ ३५.००</td>
            <td>₹ ५०.००</td>
            <td><strong>११० बॉक्स</strong></td>
            <td><span class="mini-badge badge-success">स्टॉकमध्ये</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>११ व १२. उत्पादने व स्टॉक</strong> दाबा. नवीन उत्पादनाचे नाव, खरेदी व विक्री दर आणि उपलब्ध संख्या नोंदवा. विक्री नोंदवताच स्टॉक आपोआप वजा होतो.
  </div>

  <!-- SCREEN 12: BANK LOANS & GOVT SCHEMES -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १२: बँक कर्ज व शासकीय योजना (Module 13 & 17: Bank Loans & Govt Schemes)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ बँक कर्ज नोंदवा</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>बँकेचे नाव</th>
            <th>योजनेचे नाव</th>
            <th>कर्ज मंजूर रक्कम</th>
            <th>व्याजदर (अनुदानित)</th>
            <th>मासिक हप्ता (EMI)</th>
            <th>शिल्लक मुद्दल</th>
            <th>स्थिती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>बँक ऑफ महाराष्ट्र</strong></td>
            <td>उमेद - MSRLM लिंकेज कर्ज</td>
            <td>₹ २,००,०००.००</td>
            <td>७% वार्षिक (व्याज अनुदान)</td>
            <td>₹ ४,५००.००</td>
            <td>₹ १,२०,०००.००</td>
            <td><span class="mini-badge badge-success">नियमित चालू</span></td>
          </tr>
          <tr>
            <td><strong>सोलापूर जिल्हा मध्यवर्ती बँक</strong></td>
            <td>नाबार्ड खेळते भांडवल योजना</td>
            <td>₹ ५०,०००.००</td>
            <td>४% वार्षिक</td>
            <td>₹ १,२५०.००</td>
            <td>₹ ०.००</td>
            <td><span class="mini-badge badge-info">पूर्ण फेडले</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>१३ व १७. बँक कर्ज व योजना</strong> दाबा. बँकेकडून गटाला मिळालेले मोठे कर्ज, हप्ता देय तारीख व शासनाचे व्याज अनुदान तपशील येथे ट्रॅक करा.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 13: PROFIT & LOSS STATEMENT -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १३: मासिक नफा-तोटा पत्रक (Module 15: Monthly Profit & Loss Statement)</span>
      <span class="mini-badge badge-success">आर्थिक विश्लेषण</span>
    </div>
    <div class="mockup-body">
      <div class="mini-topbar" style="margin-bottom: 6px;">
        <div><strong>आर्थिक कालावधी:</strong> सप्टेंबर २०२६ | महिना नफा-तोटा ताळेबंद</div>
        <span class="mini-badge badge-purple">निव्वळ नफा: ₹ ८,९३७.००</span>
      </div>
      <div style="display: flex; gap: 8px;">
        <div style="flex: 1; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 5px; padding: 6px;">
          <div style="font-weight: 700; color: #166534; font-size: 10px; margin-bottom: 4px;">उत्पन्न बाजू (Income / Revenue)</div>
          <table class="guide-table" style="margin: 0; font-size: 9.5px;">
            <tr><td>कर्ज व्याज जमा</td><td style="text-align: right;">₹ २,६७०.००</td></tr>
            <tr><td>उत्पादने विक्री नफा</td><td style="text-align: right;">₹ ५,५००.००</td></tr>
            <tr><td>दंड व विलंब शुल्क</td><td style="text-align: right;">₹ २२०.००</td></tr>
            <tr><td>बँक व्याज जमा</td><td style="text-align: right;">₹ ५४७.००</td></tr>
            <tr style="font-weight: 700; background: #dcfce7;"><td>एकूण उत्पन्न</td><td style="text-align: right;">₹ ८,९३७.००</td></tr>
          </table>
        </div>
        <div style="flex: 1; background: #fff1f2; border: 1px solid #fecdd3; border-radius: 5px; padding: 6px;">
          <div style="font-weight: 700; color: #9f1239; font-size: 10px; margin-bottom: 4px;">खर्च बाजू (Expenses)</div>
          <table class="guide-table" style="margin: 0; font-size: 9.5px;">
            <tr><td>स्टेशनरी व दप्तर खर्च</td><td style="text-align: right;">₹ ३५०.००</td></tr>
            <tr><td>बैठक चहापान खर्च</td><td style="text-align: right;">₹ २५०.००</td></tr>
            <tr><td>बँक कमिशन व शुल्क</td><td style="text-align: right;">₹ ५०.००</td></tr>
            <tr><td>प्रवास व वाहतूक</td><td style="text-align: right;">₹ ०.००</td></tr>
            <tr style="font-weight: 700; background: #ffe4e6;"><td>एकूण खर्च</td><td style="text-align: right;">₹ ६५०.००</td></tr>
          </table>
        </div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>१५. मासिक नफा-तोटा पत्रक</strong> दाबा. महिना निवडा. गटाचे एकूण उत्पन्न, एकूण खर्च आणि शिल्लक राहिलेला निव्वळ नफा एका दृष्टिक्षेपात पाहता येतो.
  </div>

  <!-- SCREEN 14: CONTRIBUTIONS & FINES -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १४: वर्गणी व दंड नोंदणी (Module 16: Contributions & Penalties Register)</span>
      <span class="mini-btn mini-btn-amber" style="font-size: 8.5px; padding: 2px 6px;">+ वर्गणी / दंड नोंदवा</span>
    </div>
    <div class="mockup-body">
      <div class="tabs-bar">
        <div class="tab-item active">१. वर्गणी नोंदी (Contributions)</div>
        <div class="tab-item">२. दंड नोंदी (Fines & Penalties)</div>
      </div>
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>तारीख</th>
            <th>सदस्याचे नाव</th>
            <th>प्रकार</th>
            <th>कारण / तपशील</th>
            <th>रक्कम (₹)</th>
            <th>स्थिती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>०५-०९-२०२६</td>
            <td>छाया दीपक कांबळे</td>
            <td><span class="mini-badge badge-danger">दंड</span></td>
            <td>मासिक बैठकीस पूर्वपरवानगीशिवाय गैरहजर</td>
            <td>₹ ५०.००</td>
            <td><span class="mini-badge badge-success">वसूल झाले</span></td>
          </tr>
          <tr>
            <td>०१-०९-२०२६</td>
            <td>सर्व २० सभासद</td>
            <td><span class="mini-badge badge-purple">विशेष वर्गणी</span></td>
            <td>वार्षिक हळदी-कुंकू व मेळावा निधी (प्रति सदस्य ₹ १००)</td>
            <td>₹ २,०००.००</td>
            <td><span class="mini-badge badge-success">जमा</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>१६. वर्गणी व दंड</strong> दाबा. गैरहजर दंड, हप्ता उशीर दंड किंवा इमारत निधी वर्गणी सदस्याच्या नावावर नोंदवून त्वरित पावती फाडा.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 15: RESOLUTIONS & KYC DOCUMENTS -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १५: ठराव वही व कागदपत्रे KYC (Module 18: Resolutions & Documents)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ नवीन ठराव नोंदवा</span>
    </div>
    <div class="mockup-body">
      <div class="tabs-bar">
        <div class="tab-item active">ठराव नोंदवही (Resolutions)</div>
        <div class="tab-item">सदस्य KYC कागदपत्रे (Documents)</div>
      </div>
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>ठराव क्र.</th>
            <th>तारीख</th>
            <th>ठरावाचा विषय</th>
            <th>सूचक (Proposed By)</th>
            <th>अनुमोदक</th>
            <th>निर्णय</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>RES-24/01</strong></td>
            <td>१०-०९-२०२६</td>
            <td>मीना जाधव यांना किराणा दुकानासाठी ₹ २०,००० कर्ज मंजुरी</td>
            <td>सुनंदा पवार</td>
            <td>कविता शिंदे</td>
            <td><span class="mini-badge badge-success">एकमुखाने मंजूर ✓</span></td>
          </tr>
          <tr>
            <td><strong>RES-24/02</strong></td>
            <td>१०-०९-२०२६</td>
            <td>दिवाळीनिमित्त पापड-मसाले प्रदर्शन स्टॉल लावणेबाबत</td>
            <td>लता मोरे</td>
            <td>आशा भोसले</td>
            <td><span class="mini-badge badge-success">एकमुखाने मंजूर ✓</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>१८. ठराव वही व कागदपत्रे</strong> दाबा. प्रत्येक बैठकीतील कायदेशीर ठराव, सूचक व अनुमोदकाचे नाव नोंदवून सुरक्षित ठेवा. सदस्यांचे आधार/पॅन कार्ड येथेच सेव्ह करा.
  </div>

  <!-- SCREEN 16: TRAININGS & EVENTS -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १६: कौशल्य प्रशिक्षण व उपक्रम मेळावे (Module 20 & 21: Trainings & Events)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">+ उपक्रम नोंदवा</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>उपक्रम नाव</th>
            <th>प्रकार</th>
            <th>प्रशिक्षक / संस्था</th>
            <th>कालावधी</th>
            <th>सहभागी महिला</th>
            <th>स्थिती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>खाद्यपदार्थ प्रक्रिया व पॅकिंग प्रशिक्षण</strong></td>
            <td>कौशल्य प्रशिक्षण</td>
            <td>कृषी विज्ञान केंद्र (KVK)</td>
            <td>१५ ते १८ ऑगस्ट २०२६</td>
            <td>१५ सदस्या</td>
            <td><span class="mini-badge badge-success">प्रमाणपत्र वितरित</span></td>
          </tr>
          <tr>
            <td><strong>जिल्हास्तरीय महिला बचत गट मेळावा</strong></td>
            <td>प्रदर्शन व विक्री</td>
            <td>जिल्हा परिषद, सोलापूर</td>
            <td>०२ ते ०५ ऑक्टोबर २०२६</td>
            <td>२० सदस्या</td>
            <td><span class="mini-badge badge-info">नियोजित (Upcoming)</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२० व २१. कौशल्य प्रशिक्षण</strong> दाबा. बचत गटाच्या सदस्यांनी घेतलेली व्यावसायिक प्रशिक्षणांची नोंद व प्रदर्शनांची माहिती येथे साठवा.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 17: DUES & RECOVERY REGISTER -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १७: थकबाकी व वसुली नोंदवही (Module 22: Dues & Recovery Register)</span>
      <span class="mini-btn mini-btn-amber" style="font-size: 8.5px; padding: 2px 6px;">WhatsApp स्मरणपत्र पाठवा 💬</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>सदस्याचे नाव</th>
            <th>मोबाईल</th>
            <th>कर्ज खाते क्र.</th>
            <th>थकीत महिने</th>
            <th>मुद्दल थकबाकी</th>
            <th>व्याज बाकी</th>
            <th>एकूण येणे बाकी</th>
            <th>कृती</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>लता संभाजी मोरे</strong></td>
            <td>9765123456</td>
            <td>LN-2026-004</td>
            <td>१ महिना</td>
            <td>₹ १,२५०.००</td>
            <td>₹ २५०.००</td>
            <td style="color: #dc2626; font-weight: 700;">₹ १,५००.००</td>
            <td><button class="mini-btn mini-btn-green" style="font-size: 8px; padding: 2px 5px;">हप्ता भरा</button></td>
          </tr>
          <tr>
            <td><strong>अनिता तानाजी शिंदे</strong></td>
            <td>9822334455</td>
            <td>LN-2026-007</td>
            <td>२ महिने</td>
            <td>₹ २,०००.००</td>
            <td>₹ ४००.००</td>
            <td style="color: #dc2626; font-weight: 700;">₹ २,४००.००</td>
            <td><button class="mini-btn mini-btn-green" style="font-size: 8px; padding: 2px 5px;">हप्ता भरा</button></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२२. थकबाकी व वसुली</strong> दाबा. कोणाकडे किती हप्ता बाकी आहे ते लाल रंगात दिसते. सदस्याच्या नावापुढील WhatsApp बटण दाबून त्वरित स्मरणपत्र पाठवा.
  </div>

  <!-- SCREEN 18: NOTIFICATIONS & REMINDERS -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १८: सूचना व स्मरणपत्रे (Module 23: Notifications & Reminders)</span>
      <span class="mini-badge badge-danger">३ नवीन सूचना</span>
    </div>
    <div class="mockup-body">
      <div style="background: white; border: 1px solid #fee2e2; border-left: 4px solid #ef4444; border-radius: 4px; padding: 6px 10px; margin-bottom: 6px;">
        <div style="display: flex; justify-content: space-between; font-size: 10px;">
          <strong style="color: #b91c1c;">कर्ज हप्ता देय स्मरणपत्र!</strong>
          <span style="color: #64748b; font-size: 8.5px;">आज</span>
        </div>
        <div style="font-size: 9.5px; color: #334155;">अनिता तानाजी शिंदे यांचा हप्ता ₹ १,२०० देय आहे. थकीत कालावधी: २ महिने.</div>
      </div>
      <div style="background: white; border: 1px solid #e0f2fe; border-left: 4px solid #0284c7; border-radius: 4px; padding: 6px 10px; margin-bottom: 6px;">
        <div style="display: flex; justify-content: space-between; font-size: 10px;">
          <strong style="color: #0369a1;">मासिक सभा सूचना</strong>
          <span style="color: #64748b; font-size: 8.5px;">उद्या दुपारी २:००</span>
        </div>
        <div style="font-size: 9.5px; color: #334155;">माहे सप्टेंबर मासिक सभा समाज मंदिरात आयोजित केली आहे. सर्व महिलांनी वेळेवर उपस्थित राहावे.</div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२३. सूचना व स्मरणपत्रे</strong> दाबा. येथे आगामी बैठका, थकीत कर्ज हप्ते आणि सिंक संबंधित महत्त्वाचे इशारे एकाच जागी दिसतात.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 19: ALL 38+ REPORTS & BALANCE SHEET -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन १९: ३८+ शासकीय अहवाल व ताळेबंद प्रणाली (Module 24: All Reports & Balance Sheet)</span>
      <span class="mini-btn mini-btn-blue" style="font-size: 8.5px; padding: 2px 6px;">PDF डाऊनलोड / प्रिंट 🖨️</span>
    </div>
    <div class="mockup-body">
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin-bottom: 8px;">
        <div style="background: white; border: 1px solid #cbd5e1; padding: 6px; border-radius: 5px;">
          <div style="font-weight: 600; color: #5C1D8D; font-size: 10.5px;">१. मासिक जमा-खर्च अहवाल</div>
          <div style="font-size: 8.5px; color: #64748b;">चालू महिन्याची सर्व बचत, कर्ज वसुली व खर्च सारांश.</div>
        </div>
        <div style="background: white; border: 1px solid #cbd5e1; padding: 6px; border-radius: 5px;">
          <div style="font-weight: 600; color: #5C1D8D; font-size: 10.5px;">२. वार्षिक ताळेबंद (Balance Sheet)</div>
          <div style="font-size: 8.5px; color: #64748b;">गटाची एकूण मालमत्ता, अंतर्गत कर्जे, नफा व बँक जमा.</div>
        </div>
        <div style="background: white; border: 1px solid #cbd5e1; padding: 6px; border-radius: 5px;">
          <div style="font-weight: 600; color: #5C1D8D; font-size: 10.5px;">३. सदस्य वैयक्तिक पासबुक</div>
          <div style="font-size: 8.5px; color: #64748b;">प्रत्येक सदस्याची १२ महिन्यांची बचत व कर्ज खातेवही.</div>
        </div>
      </div>
      <div style="background: white; border: 1px solid #e2e8f0; border-radius: 5px; padding: 8px;">
        <div style="text-align: center; font-weight: 700; color: #1e293b; font-size: 11px; margin-bottom: 2px;">सावित्रीबाई फुले महिला बचत गट, पंढरपूर</div>
        <div style="text-align: center; font-size: 9px; color: #64748b; margin-bottom: 6px;">मासिक ताळेबंद पत्रक - सप्टेंबर २०२६</div>
        <table class="guide-table" style="margin: 0; font-size: 9.5px;">
          <thead>
            <tr><th>जमा बाजू (Inflow / Receipts)</th><th>रक्कम (₹)</th><th>खर्च बाजू (Outflow / Payments)</th><th>रक्कम (₹)</th></tr>
          </thead>
          <tbody>
            <tr><td>मासिक बचत संकलन</td><td>₹ १०,०००.००</td><td>नवीन अंतर्गत कर्ज वाटप</td><td>₹ २०,०००.००</td></tr>
            <tr><td>कर्ज मुद्दल परतफेड</td><td>₹ १६,६६७.००</td><td>स्टेशनरी व दप्तर खर्च</td><td>₹ ३५०.००</td></tr>
            <tr><td>कर्ज व्याज जमा</td><td>₹ २,६७०.००</td><td>बैठक चहापान खर्च</td><td>₹ २५०.००</td></tr>
            <tr><td><strong>एकूण जमा (Total)</strong></td><td><strong>₹ २९,३३७.००</strong></td><td><strong>एकूण खर्च व शिल्लक</strong></td><td><strong>₹ २९,३३७.००</strong></td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२४. सर्व अहवाल</strong> दाबा. आवश्यक तो शासकीय अहवाल निवडून <strong>PDF डाऊनलोड</strong> दाबा. राष्ट्रीय ग्रामीण जीवनोन्नती अभियान (NRLM) मानकांनुसार अहवाल तयार होतो.
  </div>

  <!-- SCREEN 20: AUDIT & ACTIVITY LOG -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन २०: ऑडिट व हालचाली नोंद (Module 25: Audit & Activity Log)</span>
      <span class="mini-badge badge-success">Tamper-Proof Audit</span>
    </div>
    <div class="mockup-body">
      <table class="guide-table" style="margin: 0;">
        <thead>
          <tr>
            <th>वेळ व तारीख</th>
            <th>वापरकर्ता (User)</th>
            <th>मॉड्यूल</th>
            <th>कृती (Action)</th>
            <th>तपशील</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>१०-०९-२०२६ १४:३०</td>
            <td>सुनंदा पवार (अध्यक्षा)</td>
            <td>कर्ज वाटप</td>
            <td><span class="mini-badge badge-success">नवीन नोंद</span></td>
            <td>मीना जाधव यांना ₹ २०,००० कर्ज वाटप मंजूर केले</td>
          </tr>
          <tr>
            <td>१०-०९-२०२६ १३:१५</td>
            <td>मीना जाधव (सचिवा)</td>
            <td>मासिक बचत</td>
            <td><span class="mini-badge badge-info">जमा नोंद</span></td>
            <td>२० सदस्यांची मासिक बचत प्रत्येकी ₹ ५०० जमा नोंदवली</td>
          </tr>
          <tr>
            <td>०९-०९-२०२६ १८:००</td>
            <td>कविता शिंदे (खजिनदार)</td>
            <td>खर्च व्यवस्थापन</td>
            <td><span class="mini-badge badge-warning">व्हाउचर</span></td>
            <td>दप्तर स्टेशनरी खर्च ₹ ३५० व्हाउचर तयार केले</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२५. ऑडिट व हालचाली नोंद</strong> दाबा. कोणत्या पदाधिकाऱ्याने कोणती नोंद कधी केली, काय बदल केला याची तारीख व वेळेसह नोंद येथे पाहता येते.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 21: SETTINGS & PROFILE -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन २१: गट माहिती, पदाधिकारी व नियम (Module 26: Settings, Profile & Rules)</span>
      <span class="mini-btn mini-btn-green" style="font-size: 8.5px; padding: 2px 6px;">बदल जतन करा ✓</span>
    </div>
    <div class="mockup-body">
      <div class="tabs-bar">
        <div class="tab-item active">१. बचत गट माहिती व फोटो</div>
        <div class="tab-item">२. पदाधिकारी व नियम</div>
        <div class="tab-item">३. सुरक्षा व पिन लॉक</div>
      </div>
      <div class="mini-form-card">
        <div class="mini-form-row">
          <div class="mini-input-box" style="flex: 2;">
            <div class="mini-input-label">बचत गटाचे नाव</div>
            <div>सावित्रीबाई फुले महिला बचत गट</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">शासकीय नोंदणी क्र.</div>
            <div>MH/SOL/2024/0987</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">मासिक बचत (प्रति सदस्य)</div>
            <div>₹ ५००.००</div>
          </div>
        </div>
        <div class="mini-form-row">
          <div class="mini-input-box">
            <div class="mini-input-label">गाव / शहर</div>
            <div>पंढरपूर</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">तालुका</div>
            <div>पंढरपूर</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">जिल्हा</div>
            <div>सोलापूर</div>
          </div>
        </div>
        <div class="mini-form-row">
          <div class="mini-input-box">
            <div class="mini-input-label">अध्यक्षा नाव व फोन</div>
            <div>सुनंदा मारुती पवार (9876543210)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">सचिवा नाव व फोन</div>
            <div>मीना अशोक जाधव (9765432109)</div>
          </div>
          <div class="mini-input-box">
            <div class="mini-input-label">खजिनदार नाव व फोन</div>
            <div>कविता बापू शिंदे (9654321098)</div>
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२६. गट माहिती, फोटो व नियम</strong> दाबा. गटाचे नाव, लोगो, पदाधिकारी व मासिक बचत रक्कम नियम येथे बदलून <strong>बदल जतन करा</strong> दाबा.
  </div>

  <!-- SCREEN 22: BACKUP & RESTORE .DB -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन २२: बॅकअप व रिस्टोअर (.db) मॉड्यूल (Module 27: Backup & Restore .db System)</span>
      <span class="mini-badge badge-success">100% Data Protection</span>
    </div>
    <div class="mockup-body">
      <div style="display: flex; gap: 10px;">
        <div style="flex: 1; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 6px; padding: 10px; text-align: center;">
          <div style="font-size: 22px; margin-bottom: 2px;">💾</div>
          <div style="font-weight: 700; color: #065f46; font-size: 11px; margin-bottom: 3px;">बॅकअप एक्सपोर्ट करा (Export Backup)</div>
          <p style="font-size: 9.5px; color: #047857; margin-bottom: 8px;">सर्व सदस्य, बचत, कर्ज व हिशोबाची एक स्वतंत्र <code>.db</code> फाईल कॉम्प्युटर किंवा फोनमध्ये सेव्ह करा.</p>
          <button class="mini-btn mini-btn-green" style="padding: 5px 12px;">बॅकअप डाऊनलोड करा (.db) 📥</button>
        </div>
        <div style="flex: 1; background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 6px; padding: 10px; text-align: center;">
          <div style="font-size: 22px; margin-bottom: 2px;">🔄</div>
          <div style="font-weight: 700; color: #1e40af; font-size: 11px; margin-bottom: 3px;">बॅकअप इम्पोर्ट करा (Import / Restore)</div>
          <p style="font-size: 9.5px; color: #1d4ed8; margin-bottom: 8px;">फोन बदलल्यास किंवा नवीन डिव्हाइसवर जुनी <code>.db</code> फाईल निवडून संपूर्ण डेटा पूर्ववत करा.</p>
          <button class="mini-btn mini-btn-blue" style="padding: 5px 12px;">बॅकअप फाईल निवडा (.db) 📂</button>
        </div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>कसे वापरावे:</strong> डाव्या मेनूवरील <strong>२७. बॅकअप व रिस्टोअर (.db)</strong> दाबा. <strong>बॅकअप डाऊनलोड</strong> दाबताच सेकंदात <code>.db</code> फाईल मिळते. ही फाईल WhatsApp किंवा पेनड्राइव्हमध्ये ठेवून डेटा कधीही गमावत नाही.
  </div>

  <div class="page-break"></div>

  <!-- SCREEN 23: MOBILE PINCH-TO-ZOOM & FLOATING TOOLBAR -->
  <div class="screen-mockup">
    <div class="mockup-header">
      <div class="mockup-dots"><span class="dot-red"></span><span class="dot-yellow"></span><span class="dot-green"></span></div>
      <span>स्क्रीन २३: मोबाईल व्ह्यू, पिंच-टू-झूम व फ्लोटिंग टूलबार (Mobile Responsive & Pinch Engine)</span>
      <span class="mini-badge badge-success">Zero Overflow Guaranteed</span>
    </div>
    <div class="mockup-body" style="text-align: center; padding: 14px;">
      <div style="max-width: 290px; margin: 0 auto; background: white; border: 2.5px solid #1e293b; border-radius: 22px; padding: 12px; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.15);">
        <div style="width: 45px; height: 3.5px; background: #94a3b8; border-radius: 2px; margin: 0 auto 8px auto;"></div>
        <div style="display: flex; justify-content: space-between; align-items: center; font-size: 9.5px; margin-bottom: 6px;">
          <span>☰ सखी महिला बचत गट</span>
          <span class="mini-badge badge-success">सिंक ✓</span>
        </div>
        <div style="background: #faf5ff; border: 1px solid #d8b4fe; padding: 6px; border-radius: 5px; text-align: left; font-size: 9.5px; margin-bottom: 6px;">
          <div style="font-weight: 700; color: #5C1D8D;">मासिक बचत संकलन (मोबाईल)</div>
          <div style="color: #64748b; font-size: 8.5px;">सप्टेंबर २०२६ मासिक हिशोब</div>
        </div>
        <div style="display: flex; gap: 4px; margin-bottom: 8px;">
          <div style="flex: 1; background: #2563eb; color: white; padding: 5px; border-radius: 4px; font-size: 8.5px;">सदस्य: <strong>२०</strong></div>
          <div style="flex: 1; background: #10b981; color: white; padding: 5px; border-radius: 4px; font-size: 8.5px;">बचत: <strong>₹ १०,०००</strong></div>
        </div>
        <!-- Floating Zoom Toolbar Box -->
        <div style="background: #0f172a; color: white; border-radius: 20px; padding: 4px 10px; display: flex; justify-content: space-between; align-items: center; font-size: 9.5px; box-shadow: 0 2px 8px rgba(0,0,0,0.3);">
          <span style="cursor: pointer; padding: 1px 4px;">➖</span>
          <span style="color: #38bdf8; font-weight: 700;">100%</span>
          <span style="cursor: pointer; padding: 1px 4px;">➕</span>
          <span style="background: #334155; padding: 1px 6px; border-radius: 10px; font-size: 8px;">Fit</span>
          <span style="color: #94a3b8; cursor: pointer;">✕</span>
        </div>
      </div>
    </div>
  </div>
  <div class="step-desc">
    <strong>मोबाईलवरील विशेष कार्यपद्धती:</strong>
    <ol>
      <li><strong>दोन बोटांनी झूम (Pinch-to-Zoom):</strong> स्क्रीनवर दोन बोटांनी फोटोसारखे झूम-इन किंवा झूम-आउट करता येते.</li>
      <li><strong>फ्लोटिंग टूलबार (Floating Toolbar):</strong> स्क्रीनच्या खालील टूलबारमधील <code>+</code> आणि <code>-</code> ने स्क्रीन मोठी-लहान करा, <code>Fit</code> ने स्क्रीन स्क्रीनच्या आकाराशी जुळवून घेते. <code>✕</code> दाबताच टूलबार बाजूला सरकतो.</li>
      <li><strong>शून्य ओव्हरफ्लो (Zero Overflow):</strong> मोबाईलवर कीबोर्ड उघडला तरी इनपुट बॉक्स झाकले जात नाहीत व स्क्रीन सुरळीत स्क्रोल होते.</li>
    </ol>
  </div>

  <!-- भाग ३: तांत्रिक तपशील व सुरक्षा मार्गदर्शिका -->
  <div class="section-title">
    <span>भाग ३: डेटा सुरक्षा, बॅकअप सुसंगतता व ऑफलाइन-ऑनलाइन सिंक (Technical Architecture)</span>
  </div>

  <table class="guide-table">
    <thead>
      <tr>
        <th style="width: 25%;">घटक / वैशिष्ट्य</th>
        <th style="width: 35%;">Windows Edition</th>
        <th style="width: 40%;">Android Edition</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>बॅकअप फाईल प्रकार</strong></td>
        <td><code>.db</code> (SQLite ३.० मानक डेटाबेस)</td>
        <td><code>.db</code> (SQLite ३.० मानक डेटाबेस)</td>
      </tr>
      <tr>
        <td><strong>इम्पोर्ट / एक्सपोर्ट क्रॉस-सुसंगतता</strong></td>
        <td>Android वरून घेतलेली <code>.db</code> Windows वर चालते.</td>
        <td>Windows वरून घेतलेली <code>.db</code> Android वर चालते.</td>
      </tr>
      <tr>
        <td><strong>ऑफलाइन डेटा जतन</strong></td>
        <td>स्थानिक डिस्कवर कायमस्वरूपी सुरक्षित.</td>
        <td>मोबाईलच्या अंतर्गत मेमरीमध्ये सुरक्षित.</td>
      </tr>
      <tr>
        <td><strong>डेल्टा सिंक (Delta Sync)</strong></td>
        <td>इंटरनेट मिळताच फक्त नवीन बदल सिंक होतात.</td>
        <td>इंटरनेट मिळताच फक्त नवीन बदल सिंक होतात.</td>
      </tr>
      <tr>
        <td><strong>शासकीय अहवाल प्रिंटिंग</strong></td>
        <td>A4 आकाराच्या PDF प्रिंटरवर थेट प्रिंट.</td>
        <td>मोबाईलवरून WhatsApp / शेअर / वायरलेस प्रिंट.</td>
      </tr>
    </tbody>
  </table>

  <div class="footer-note">
    &copy; २०२६ सखी महिला बचत गट व्यवस्थापन प्रणाली | अधिकृत ग्राहक वापर पुस्तिका व सर्व २३ स्क्रीन्स सचित्र मार्गदर्शिका | सर्व हक्क राखीव.
  </div>

</div>

</body>
</html>
"""

with open(r"e:\BachatgatManagement\manual.html", "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"Successfully generated master manual.html with length: {len(html_content)} characters")
