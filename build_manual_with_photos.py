# -*- coding: utf-8 -*-
"""
build_manual_with_photos.py
Generates the complete customer manual HTML embedding ALL 23 actual screen PNG photos.
Then renders it into Sakhi_Bachat_Gat_User_Manual.pdf using headless Chrome.
"""

import os
import subprocess

MANUAL_HTML = r"e:\BachatgatManagement\manual.html"
PDF_OUT = r"e:\BachatgatManagement\Sakhi_Bachat_Gat_User_Manual.pdf"
CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

MODULES_DATA = [
    {
        "num": "१",
        "title": "स्क्रीन १: लॉगिन व ऑथेंटिकेशन (Login & PIN Authentication)",
        "badge": "सुरक्षित प्रवेशद्वार",
        "badge_cls": "badge-success",
        "img": "screenshots/01_login.png",
        "desc": [
            "नोंदणीकृत मोबाईल नंबर किंवा ईमेल आणि संकेतशब्द (Password) प्रविष्ट करा.",
            "<strong>लॉगिन करा (Login)</strong> बटणावर क्लिक करा.",
            "<strong>ऑफलाइन आवृत्ती:</strong> गावात इंटरनेट नसतानाही डीफॉल्ट ॲडमिन पिन <code>1234</code> वापरून त्वरित लॉगिन होते."
        ],
        "tip": "मोबाईल नंबर सुरक्षित ठेवा. पासवर्ड विसरल्यास 'Forgot Password' पर्यायाने नवीन पिन मिळवता येतो."
    },
    {
        "num": "२",
        "title": "स्क्रीन २: मुख्य डॅशबोर्ड व मेनू बार (Module 3: Master Dashboard & Sidebar)",
        "badge": "थेट आढावा (Live)",
        "badge_cls": "badge-success",
        "img": "screenshots/02_dashboard.png",
        "desc": [
            "ॲप सुरू होताच संपूर्ण बचत गटाचा मुख्य कार्यकारी डॅशबोर्ड उघडतो.",
            "<strong>८ मुख्य KPI कार्ड्स:</strong> एकूण सदस्य (२०), जमा बचत (₹१,२५,०००), सक्रिय अंतर्गत कर्जे (₹८५,०००), थकीत हप्ते (₹३,८६६), बँक शिल्लक (₹४५,०००), पेटीतील रोख (₹९,१३४), चालू महिना जमा (₹२९,३३७) आणि चालू महिना खर्च (₹२०,६५०) स्पष्ट दिसतात.",
            "डाव्या बाजूच्या जांभळ्या मेनू बारवरील कोणत्याही पर्यायावर क्लिक करून थेट त्या विभागात जाता येते."
        ],
        "tip": "वर उजवीकडे हिरवा 🟢 ऑनलाइन सिंक बॅज दिसल्यास तुमचा डेटा सुरक्षितपणे क्लाउडवर सेव्ह झालेला असतो."
    },
    {
        "num": "३",
        "title": "स्क्रीन ३: सदस्य व्यवस्थापन व प्रोफाइल (Module 4: Members & Profiles)",
        "badge": "१००% KYC",
        "badge_cls": "badge-purple",
        "img": "screenshots/03_members.png",
        "desc": [
            "डाव्या मेनूवरील <strong>४. सदस्य व्यवस्थापन</strong> बटणावर क्लिक करा.",
            "नवीन सभासद जोडण्यासाठी वर उजवीकडील <strong>+ नवीन सदस्य जोडा</strong> बटण दाबा.",
            "सभासदाचे पूर्ण नाव, मोबाईल नंबर, पद (अध्यक्षा/सचिवा/खजिनदार/सदस्य), आधार क्रमांक, बँक खाते व वारसदाराचे नाव भरून सेव्ह करा.",
            "प्रत्येक सदस्यासमोरील <strong>पासबुक 📖</strong> बटणावर क्लिक केल्यास त्यांचे वैयक्तिक पासबुक उघडते."
        ],
        "tip": "सदस्य कोड (उदा. MBG-001) स्वयंचलित तयार होतो, जो शासकीय अनुदानाच्या नोंदीसाठी उपयुक्त ठरतो."
    },
    {
        "num": "४",
        "title": "स्क्रीन ४: मासिक बचत संकलन व पावती (Module 5: Monthly Savings)",
        "badge": "दरमहा बचत",
        "badge_cls": "badge-success",
        "img": "screenshots/04_savings.png",
        "desc": [
            "डाव्या मेनूवरील <strong>५. मासिक बचत नोंद</strong> बटण दाबा.",
            "<strong>सभासद निवडा</strong> ड्रॉपडाउनमधून बचत भरणाऱ्या महिलेचे नाव निवडा.",
            "बचत रक्कम (उदा. ₹ ५००) तपासा आणि भरणा माध्यम (रोख/UPI/बँक) निवडून <strong>बचत जमा करा</strong> दाबा.",
            "स्क्रीनवर तात्काळ <strong>अधिकृत डिजिटल बचत पावती</strong> तयार होते, जी प्रिंट करता येते किंवा WhatsApp वर पाठवता येते."
        ],
        "tip": "बचत जमा होताच सदस्याची एकूण बचत रक्कम व गटाची पेटीतील रोख शिल्लक आपोआप वाढते."
    },
    {
        "num": "५",
        "title": "स्क्रीन ५: अंतर्गत कर्ज वाटप व EMI गणकयंत्र (Module 6: Internal Loan Disbursal)",
        "badge": "कर्ज मंजुरी",
        "badge_cls": "badge-warning",
        "img": "screenshots/05_loan_disbursal.png",
        "desc": [
            "डाव्या मेनूवरील <strong>६ व ७. कर्ज वाटप</strong> दाबा आणि <strong>+ नवीन कर्ज वाटप फॉर्म</strong> उघडा.",
            "कर्जदार सभासद, कर्ज रक्कम (उदा. ₹ २०,०००), मुदत (उदा. १२ महिने), व्याजदर (उदा. २% दरमहा) भरा.",
            "गटातील २ जबाबदार जामीनदार सदस्यांची नावे व कर्जाचा हेतू (उदा. किराणा दुकान) प्रविष्ट करा.",
            "खालील EMI गणकयंत्र आपोआप मासिक मुद्दल (₹ १,६६७) आणि व्याज (₹ ४००) मोजून एकूण EMI (₹ २,०६७) दाखवते.",
            "<strong>कर्ज मंजूर करा</strong> बटण दाबताच कर्ज करारनामा व पावती तयार होते."
        ],
        "tip": "कर्ज वाटप करताना २ जामीनदारांची संमती घेणे बचत गटाच्या नियमांनुसार बंधनकारक आहे."
    },
    {
        "num": "६",
        "title": "स्क्रीन ६: कर्ज हप्ता वसुली व परतफेड (Module 7: Collect EMI & Repayments)",
        "badge": "हप्ता संकलन",
        "badge_cls": "badge-success",
        "img": "screenshots/06_collect_emi.png",
        "desc": [
            "सक्रिय कर्जांच्या यादीत संबंधित कर्जदार सदस्यासमोरील <strong>हप्ता भरा (Collect)</strong> बटण दाबा.",
            "प्रणाली आपोआप चालू महिन्याची मुद्दल, व्याज आणि विलंब असल्यास दंड स्वतंत्रपणे मोजून दाखवते.",
            "<strong>हप्ता जमा करा</strong> दाबताच उर्वरित मुद्दल शिल्लक कमी होते आणि रक्कम रोख वहीत जमा होते."
        ],
        "tip": "हप्ता जमा झाल्यावर सदस्याला तात्काळ मुद्दल व व्याज विभाजन दाखवणारी पावती मिळते."
    },
    {
        "num": "७",
        "title": "स्क्रीन ७: मासिक बैठका व हजेरी नोंदवही (Module 7b: Meetings & Attendance)",
        "badge": "इतिवृत्त वही",
        "badge_cls": "badge-info",
        "img": "screenshots/07_meetings.png",
        "desc": [
            "डाव्या मेनूवरील <strong>७b. मासिक बैठका व हजेरी</strong> दाबा.",
            "<strong>+ नवीन बैठक आयोजित करा</strong> वरून बैठकीची तारीख (उदा. १०-०९-२०२६), वेळ, स्थान व विषयपत्रिका नोंदवा.",
            "बैठकीदरम्यान सर्व सदस्यांची हजेरी (हजर / गैरहजर) नोंदवा.",
            "पूर्वपरवानगीशिवाय गैरहजर राहिलेल्या सदस्यावर एका क्लिकवर <strong>₹ ५० गैरहजर दंड</strong> आकारला जातो."
        ],
        "tip": "शासकीय तपासणीच्या वेळी बैठकीची हजेरी आणि इतिवृत्त अत्यंत महत्त्वाचे मानले जाते."
    },
    {
        "num": "८",
        "title": "स्क्रीन ८: उत्पन्न व्यवस्थापन व पावती नोंद (Module 8: Income Management)",
        "badge": "गट महसूल",
        "badge_cls": "badge-success",
        "img": "screenshots/08_income.png",
        "desc": [
            "डाव्या मेनूवरील <strong>८. उत्पन्न व्यवस्थापन</strong> बटण दाबा.",
            "<strong>+ उत्पन्न नोंदवा</strong> वर क्लिक करून उत्पन्नाची वर्गवारी निवडा (कर्ज व्याज, उत्पादने विक्री नफा, शासकीय अनुदान, प्रवेश फी).",
            "रक्कम, पावती क्रमांक आणि जमा खाते (रोख किंवा बँक) निवडून सेव्ह करा."
        ],
        "tip": "उमेद (MSRLM) कडून मिळालेला फिरता निधी किंवा शासकीय अनुदान येथेच नोंदवावे."
    },
    {
        "num": "९",
        "title": "स्क्रीन ९: खर्च व्यवस्थापन व व्हाउचर्स (Module 9: Expense Management)",
        "badge": "खर्च ताळेबंद",
        "badge_cls": "badge-warning",
        "img": "screenshots/09_expense.png",
        "desc": [
            "डाव्या मेनूवरील <strong>९. खर्च व्यवस्थापन</strong> दाबा.",
            "<strong>+ खर्च व्हाउचर तयार करा</strong> दाबा &rarr; खर्चाचा प्रकार निवडा (स्टेशनरी व वह्या, चहापान, प्रवास, बँक शुल्क).",
            "दुकानदाराचे नाव, बिल नंबर व रक्कम भरून सेव्ह करा. खर्च रोख वहीत आपोआप नावे (Debit) होतो."
        ],
        "tip": "दर बैठकीच्या शेवटी अध्यक्षा व खजिनदारांनी सर्व खर्च व्हाउचर तपासून स्वाक्षरी करावी."
    },
    {
        "num": "१०",
        "title": "स्क्रीन १०: बँक खाती व रोख वही (Module 10 & 14: Bank & Cash Book)",
        "badge": "दैनिक रोख वही",
        "badge_cls": "badge-success",
        "img": "screenshots/10_cashbook.png",
        "desc": [
            "डाव्या मेनूवरील <strong>१० व १४. बँक व कॅश बुक</strong> दाबा.",
            "हातातील रोख शिल्लक (Cash in Hand ₹ ९,१३४) आणि बँक ऑफ महाराष्ट्र खात्यातील शिल्लक (₹ ४५,०००) एकाच जागी पहा.",
            "प्रत्येक दिवसाचे जमा (Credit) आणि खर्च (Debit) व्यवहार क्रमाने तारखेनुसार तपासता येतात."
        ],
        "tip": "प्रत्येक महिन्याच्या शेवटी <strong>कॅश बुक PDF</strong> डाऊनलोड करून बँक पासबुकसोबत जुळवून घ्यावे."
    },
    {
        "num": "११",
        "title": "स्क्रीन ११: उत्पादने व स्टॉक POS (Module 11 & 12: Products & Inventory POS)",
        "badge": "लघुउद्योग",
        "badge_cls": "badge-purple",
        "img": "screenshots/11_inventory.png",
        "desc": [
            "डाव्या मेनूवरील <strong>११ व १२. उत्पादने व स्टॉक POS</strong> दाबा.",
            "गटाचे लघुउद्योग उत्पादने जसे की उडीद पापड, लोणचे, गरम मसाले, अगरबत्ती यांची नोंद करा.",
            "खरेदी खर्च, विक्री दर आणि शिल्लक स्टॉक संख्या ट्रॅक करा.",
            "<strong>विक्री बिल (POS)</strong> वरून ग्राहकास तात्काळ छापील पावती देता येते आणि स्टॉक आपोआप कमी होतो."
        ],
        "tip": "मेळाव्यात किंवा स्थानिक बाजारात थेट विक्री करताना POS बिलिंग अत्यंत फायदेशीर ठरते."
    },
    {
        "num": "१२",
        "title": "स्क्रीन १२: बँक कर्ज व शासकीय योजना (Module 13 & 17: Bank Loans & Schemes)",
        "badge": "शासकीय योजना",
        "badge_cls": "badge-info",
        "img": "screenshots/12_bank_loans.png",
        "desc": [
            "डाव्या मेनूवरील <strong>१३ व १७. बँक कर्ज व योजना</strong> दाबा.",
            "बँक ऑफ महाराष्ट्र, SBI किंवा जिल्हा मध्यवर्ती बँकेकडून घेतलेले मोठे कर्ज (उदा. ₹ २,००,०००) नोंदवा.",
            "उमेद - MSRLM व्याज अनुदान योजना, मासिक बँक हप्ता (EMI) व शिल्लक मुद्दल ट्रॅक करा."
        ],
        "tip": "वेळेवर बँक हप्ता भरल्यास शासनाकडून नियमित व्याज अनुदान (Interest Subvention) प्राप्त होते."
    },
    {
        "num": "१३",
        "title": "स्क्रीन १३: मासिक नफा-तोटा ताळेबंद (Module 15: Profit & Loss Statement)",
        "badge": "नफा विश्लेषण",
        "badge_cls": "badge-success",
        "img": "screenshots/13_profit_loss.png",
        "desc": [
            "डाव्या मेनूवरील <strong>१५. मासिक नफा-तोटा पत्रक</strong> दाबा.",
            "चालू महिन्यातील एकूण जमा महसूल (₹ ८,९३७) आणि एकूण प्रशासकीय खर्च (₹ ६५०) यातील फरक काढून निव्वळ नफा (₹ ८,२८७) स्वयंचलित मोजला जातो.",
            "हा नफा वर्षाच्या शेवटी सर्व २० सदस्यांमध्ये त्यांच्या बचतीच्या प्रमाणात लाभांश (Dividend) म्हणून वाटप करता येतो."
        ],
        "tip": "गटाची आर्थिक प्रगती आणि नफा पारदर्शकपणे सर्व महिलांना दाखवण्यासाठी हे पत्रक वापरावे."
    },
    {
        "num": "१४",
        "title": "स्क्रीन १४: वर्गणी व दंड नोंदणी वही (Module 16: Contributions & Fines)",
        "badge": "अनुशासन व निधी",
        "badge_cls": "badge-warning",
        "img": "screenshots/14_contributions_fines.png",
        "desc": [
            "डाव्या मेनूवरील <strong>१६. वर्गणी व दंड नोंद</strong> दाबा.",
            "<strong>१. वर्गणी टॅब:</strong> वार्षिक सण, हळदी-कुंकू किंवा इमारत निधी वर्गणी सदस्यांच्या खात्यावर नोंदवा.",
            "<strong>२. दंड टॅब:</strong> बैठकीस गैरहजर दंड (₹ ५०) किंवा हप्ता विलंब दंड नोंदवून तात्काळ वसूल करा."
        ],
        "tip": "दंडाची रक्कम ही गटाचे अतिरिक्त उत्पन्न मानली जाते आणि नफा-तोटा पत्रकात जमा होते."
    },
    {
        "num": "१५",
        "title": "स्क्रीन १५: ठराव वही व KYC कागदपत्रे (Module 18: Resolutions & Documents)",
        "badge": "कायदेशीर ठराव",
        "badge_cls": "badge-purple",
        "img": "screenshots/15_resolutions_kyc.png",
        "desc": [
            "डाव्या मेनूवरील <strong>१८. ठराव वही व कागदपत्रे</strong> दाबा.",
            "मासिक बैठकीत मंजूर झालेले ठराव (उदा. कर्ज वाटप मंजुरी, मेळावा स्टॉल मंजुरी) सूचक व अनुमोदकासह नोंदवा.",
            "सदस्यांचे आधार कार्ड, पॅन कार्ड, बँक पासबुक व कर्ज करारनामे सुरक्षितपणे डिजिटली साठवा."
        ],
        "tip": "बँकेत नवीन खाते उघडताना किंवा शासकीय अनुदानासाठी ठराव वहीची प्रमाणित प्रत आवश्यक असते."
    },
    {
        "num": "१६",
        "title": "स्क्रीन १६: कौशल्य प्रशिक्षण व उपक्रम मेळावे (Module 20 & 21: Trainings & Events)",
        "badge": "महिला सक्षमीकरण",
        "badge_cls": "badge-info",
        "img": "screenshots/16_trainings_events.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२० व २१. कौशल्य प्रशिक्षण</strong> दाबा.",
            "कृषी विज्ञान केंद्र किंवा उमेद कडून घेतलेले अन्न प्रक्रिया, पॅकिंग, शिलाई काम शिबिरांची नोंद करा.",
            "जिल्हा परिषद व शासकीय मेळाव्यात लावलेल्या स्टॉलची माहिती व विक्री आकडेवारी साठवा."
        ],
        "tip": "प्रशिक्षण घेतलेल्या सदस्यांना शासकीय ग्रेडिंगमध्ये प्राधान्य दिले जाते."
    },
    {
        "num": "१७",
        "title": "स्क्रीन १७: थकबाकी व वसुली नोंदवही (Module 22: Dues & Recovery Register)",
        "badge": "थकबाकी नियंत्रण",
        "badge_cls": "badge-danger",
        "img": "screenshots/17_dues_recovery.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२२. थकबाकी व वसुली</strong> दाबा.",
            "कोणाकडे किती महिने कर्ज हप्ता किंवा मासिक बचत बाकी आहे ते ठळक लाल रंगात दिसते.",
            "सदस्याच्या नावापुढील <strong>WhatsApp 💬</strong> बटण दाबताच थेट थकबाकीचे स्मरणपत्र पाठवले जाते."
        ],
        "tip": "मासिक बैठकीच्या ३ दिवस आधी सर्व थकबाकीदारांना WhatsApp स्मरणपत्र पाठवणे सोपे होते."
    },
    {
        "num": "१८",
        "title": "स्क्रीन १८: सूचना व स्मरणपत्रे (Module 23: Notifications & Reminders)",
        "badge": "सूचना केंद्र",
        "badge_cls": "badge-info",
        "img": "screenshots/18_notifications.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२३. सूचना व स्मरणपत्रे</strong> दाबा.",
            "कर्ज हप्ता देय तारखांचे स्वयंचलित इशारे, आगामी मासिक सभेची सूचना व क्लाउड सिंक यशस्वीतेचे संदेश येथे दिसतात."
        ],
        "tip": "महत्त्वाचे अलर्ट वेळेवर मिळाल्यामुळे कोणताही आर्थिक व्यवहार चुकत नाही."
    },
    {
        "num": "१९",
        "title": "स्क्रीन १९: ३८+ शासकीय अहवाल व ताळेबंद प्रणाली (Module 24: All Reports)",
        "badge": "शासकीय PDF",
        "badge_cls": "badge-success",
        "img": "screenshots/19_all_reports.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२४. सर्व अहवाल (Reports)</strong> दाबा.",
            "मासिक अहवाल, वार्षिक ताळेबंद (Balance Sheet), सदस्य वैयक्तिक पासबुक, वसुली तक्ता यापैकी हवा तो अहवाल निवडा.",
            "<strong>PDF डाऊनलोड / प्रिंट 🖨️</strong> बटणावर क्लिक करा. NRLM मानकांनुसार अध्यक्षा, सचिवा व खजिनदार स्वाक्षरी जागेसह अधिकृत अहवाल मिळतो."
        ],
        "tip": "वार्षिक ऑडिटच्या वेळी हे ३८+ शासकीय अहवाल एका क्लिकवर प्रिंट करून सादर करता येतात."
    },
    {
        "num": "२०",
        "title": "स्क्रीन २०: ऑडिट ट्रेल व हालचाली नोंद (Module 25: Audit Log & Security)",
        "badge": "सुरक्षित ऑडिट",
        "badge_cls": "badge-purple",
        "img": "screenshots/20_audit_log.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२५. ऑडिट व हालचाली नोंद</strong> दाबा.",
            "कोणत्या पदाधिकाऱ्याने कोणती नोंद कधी केली, काय बदल केला, किती रकमेचा व्यवहार केला याची वेळ व तारीखसह अखंड नोंद राहते."
        ],
        "tip": "हा डेटा फेरफार-प्रतिबंधित (Tamper-proof) असतो, ज्यामुळे बचत गटात १००% पारदर्शकता राहते."
    },
    {
        "num": "२१",
        "title": "स्क्रीन २१: गट माहिती, पदाधिकारी व नियम (Module 26: Settings & Profile)",
        "badge": "गट नियम",
        "badge_cls": "badge-info",
        "img": "screenshots/21_settings_profile.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२६. गट माहिती व नियम</strong> दाबा.",
            "गटाचे नाव, शासकीय नोंदणी क्रमांक, गाव, तालुका, अध्यक्षा, सचिवा व खजिनदार यांचे नाव व मोबाईल नंबर अद्ययावत करा.",
            "मासिक बचत रक्कम (उदा. ₹ ५००) व अंतर्गत कर्ज व्याजदर नियम येथे सेट करा."
        ],
        "tip": "नवीन पदाधिकारी निवड झाल्यावर त्यांचे नाव व फोन नंबर येथेच बदलून 'बदल जतन करा' दाबावे."
    },
    {
        "num": "२२",
        "title": "स्क्रीन २२: बॅकअप व रिस्टोअर (.db) मॉड्यूल (Module 27: Backup & Restore .db)",
        "badge": "१००% डेटा सुरक्षा",
        "badge_cls": "badge-success",
        "img": "screenshots/22_backup_restore.png",
        "desc": [
            "डाव्या मेनूवरील <strong>२७. बॅकअप व रिस्टोअर (.db)</strong> दाबा.",
            "<strong>बॅकअप डाऊनलोड करा (.db):</strong> संपूर्ण डेटाबेसची सुरक्षित SQLite <code>.db</code> फाईल कॉम्प्युटर किंवा पेनड्राइव्हमध्ये सेव्ह करा.",
            "<strong>बॅकअप इम्पोर्ट करा:</strong> संगणक किंवा फोन बदलल्यास जुनी <code>.db</code> फाईल निवडून १ सेकंदात सर्व डेटा पूर्ववत करा."
        ],
        "tip": "Windows व Android दोन्ही आवृत्त्यांमध्ये एकाच प्रकारची .db फाईल चालते (100% Cross-Compatible)."
    },
    {
        "num": "२३",
        "title": "स्क्रीन २३: मोबाईल व्ह्यू, पिंच-टू-झूम व फ्लोटिंग टूलबार (Mobile Responsive & Pinch Engine)",
        "badge": "Zero Overflow",
        "badge_cls": "badge-success",
        "img": "screenshots/23_mobile_zoom.png",
        "desc": [
            "<strong>दोन बोटांनी झूम (Pinch-to-Zoom):</strong> मोबाईल स्क्रीनवर दोन बोटांनी फोटोसारखे झूम-इन किंवा झूम-आउट करता येते.",
            "<strong>फ्लोटिंग झूम टूलबार:</strong> खालील टूलबारमधील <code>+</code> आणि <code>-</code> ने स्क्रीन नियंत्रित करा, <code>Fit</code> ने स्क्रीन आकाराशी जुळवून घेते आणि <code>✕</code> ने टूलबार छोटा होतो.",
            "<strong>शून्य ओव्हरफ्लो:</strong> मोबाईलवर कीबोर्ड उघडला तरी इनपुट बॉक्स झाकले जात नाहीत व स्क्रीन सुरळीत स्क्रोल होते."
        ],
        "tip": "गावातील महिलांना बारीक अक्षरे वाचणे कठीण गेल्यास दोन बोटांनी स्क्रीन सहज मोठी करता येते."
    }
]

html = """<!DOCTYPE html>
<html lang="mr">
<head>
  <meta charset="UTF-8">
  <title>सखी महिला बचत गट व्यवस्थापन प्रणाली - अधिकृत ग्राहक वापर पुस्तिका व सर्व २३ स्क्रीन्स सचित्र मार्गदर्शिका</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;500;600;700&family=Poppins:wght@400;500;600;700&display=swap');

    @page {
      size: A4;
      margin: 8mm 10mm;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: 'Noto Sans Devanagari', 'Poppins', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #0f172a;
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

    .header-banner {
      background: linear-gradient(135deg, #2e1065 0%, #5c1d8d 50%, #7e22ce 100%);
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

    .pills-row {
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

    .section-title {
      font-size: 13.5px;
      font-weight: 700;
      color: #5c1d8d;
      border-left: 5px solid #5c1d8d;
      padding: 6px 12px;
      margin-top: 16px;
      margin-bottom: 12px;
      background: #faf5ff;
      border-radius: 0 6px 6px 0;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

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
      background: #5c1d8d;
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

    table.guide-table tr:nth-child(even) { background: #f8fafc; }

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

    /* Module Photo Card */
    .screen-block {
      background: #ffffff;
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      padding: 12px 14px;
      margin-bottom: 18px;
      page-break-inside: avoid;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    }

    .screen-block-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
      padding-bottom: 6px;
      border-bottom: 1px solid #e2e8f0;
    }

    .screen-block-header h3 {
      font-size: 12.5px;
      font-weight: 700;
      color: #1e1b4b;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .badge-label {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 9px;
      font-weight: 600;
    }

    .badge-success { background: #dcfce7; color: #15803d; }
    .badge-purple { background: #f3e8ff; color: #7c3aed; }
    .badge-warning { background: #fef3c7; color: #b45309; }
    .badge-danger { background: #fee2e2; color: #b91c1c; }
    .badge-info { background: #e0f2fe; color: #0369a1; }

    .screen-photo {
      width: 100%;
      height: auto;
      border-radius: 6px;
      border: 1px solid #cbd5e1;
      box-shadow: 0 3px 10px rgba(0, 0, 0, 0.08);
      margin-bottom: 8px;
      display: block;
    }

    .steps-box {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-left: 3.5px solid #5c1d8d;
      border-radius: 0 5px 5px 0;
      padding: 8px 12px;
      font-size: 10px;
    }

    .steps-box ol {
      margin-left: 16px;
      margin-top: 3px;
    }

    .steps-box li {
      margin-bottom: 3px;
      color: #334155;
    }

    .tip-box {
      font-size: 9.5px;
      color: #475569;
      margin-top: 5px;
      padding-top: 4px;
      border-top: 1px dashed #cbd5e1;
    }

    .page-break { page-break-after: always; }

    .footer-note {
      text-align: center;
      font-size: 9px;
      color: #94a3b8;
      border-top: 1px solid #e2e8f0;
      padding-top: 8px;
      margin-top: 16px;
    }
  </style>
</head>
<body>

<div class="container">

  <!-- COVER HEADER -->
  <div class="header-banner">
    <h1>सखी महिला बचत गट व्यवस्थापन प्रणाली</h1>
    <h2>अधिकृत ग्राहक वापर पुस्तिका व सर्व २३ स्क्रीन्स सचित्र मार्गदर्शिका</h2>
    <div class="pills-row">
      <span class="badge-pill">संस्करण २.० (२०२६ अधिकृत आवृत्ती)</span>
      <span class="badge-pill">Windows & Android सपोर्ट</span>
      <span class="badge-pill">प्रत्यक्ष स्क्रीन्सचे खरे फोटो (Actual Screen Photos)</span>
      <span class="badge-pill">१००% डेटा सुरक्षा व स्थानिक बॅकअप (.db)</span>
    </div>
  </div>

  <!-- भाग १: जलद संदर्भ तक्ता -->
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
      <tr><td><strong>१. लॉगिन / पिन बदलणे</strong></td><td><span class="btn-tag">१. लॉगिन व ऑथेंटिकेशन</span></td><td>मोबाईल नंबर व पासवर्ड टाका. ऑफलाइनसाठी डीफॉल्ट पिन <code>1234</code> वापरा.</td></tr>
      <tr><td><strong>२. गटाचा संपूर्ण आढावा पाहणे</strong></td><td><span class="btn-tag">३. मुख्य डॅशबोर्ड</span></td><td>बचत, रोख, बँक, कर्जे, थकीत हप्ते व उत्पन्न-खर्च एकाच दृष्टिक्षेपात पहा.</td></tr>
      <tr><td><strong>३. नवीन सदस्य जोडणे / KYC</strong></td><td><span class="btn-tag">४. सदस्य व्यवस्थापन</span></td><td><strong>+ नवीन सदस्य जोडा</strong> दाबा &rarr; नाव, पत्ता, बँक खाते, आधार व वारसदार नोंदवा.</td></tr>
      <tr><td><strong>४. मासिक बचत जमा करणे</strong></td><td><span class="btn-tag">५. मासिक बचत नोंद</span></td><td>सदस्य निवडा &rarr; बचत रक्कम भरा &rarr; माध्यम निवडून बचत पावती द्या.</td></tr>
      <tr><td><strong>५. अंतर्गत कर्ज मंजूर करणे</strong></td><td><span class="btn-tag">६. कर्ज वाटप (Loan Disburse)</span></td><td>सदस्य, रक्कम, मुदत, २ जामीनदार निवडून EMI तपासा व कर्ज मंजूर करा.</td></tr>
      <tr><td><strong>६. कर्जाचा मासिक हप्ता भरणे</strong></td><td><span class="btn-tag">७. हप्ता वसुली (Collect EMI)</span></td><td>सदस्यासमोरील <strong>हप्ता भरा</strong> दाबा &rarr; मुद्दल व व्याज तपासा &rarr; पावती द्या.</td></tr>
      <tr><td><strong>७. मासिक बैठक व हजेरी नोंद</strong></td><td><span class="btn-tag">७b. मासिक बैठका व हजेरी</span></td><td>बैठक तारीख, अजेंडा भरा &rarr; सदस्यांची हजेरी नोंदवून गैरहजर दंड आकारा.</td></tr>
      <tr><td><strong>८. गटाचे उत्पन्न नोंदवणे</strong></td><td><span class="btn-tag">८. उत्पन्न व्यवस्थापन</span></td><td>विक्री, बँक व्याज, अनुदान निवडून पावती नंबर व रक्कम सेव्ह करा.</td></tr>
      <tr><td><strong>९. गटाचा खर्च नोंदवणे</strong></td><td><span class="btn-tag">९. खर्च व्यवस्थापन</span></td><td>स्टेशनरी, चहापान, प्रवास खर्च व्हाउचर तयार करून रक्कम नोंदवा.</td></tr>
      <tr><td><strong>१०. रोख व बँक शिल्लक तपासणे</strong></td><td><span class="btn-tag">१० व १४. बँक व कॅश बुक</span></td><td>हातातील रोख शिल्लक व बँक खात्यातील शिल्लक तपासा; रोजचे व्यवहार पहा.</td></tr>
      <tr><td><strong>११. उत्पादने स्टॉक व विक्री</strong></td><td><span class="btn-tag">११ व १२. उत्पादने व स्टॉक POS</span></td><td>पापड, लोणचे, मसाले स्टॉक नोंदवा &rarr; <strong>विक्री बिल (POS)</strong> द्या.</td></tr>
      <tr><td><strong>१२. बँकेचे कर्ज व शासकीय योजना</strong></td><td><span class="btn-tag">१३ व १७. बँक कर्ज व योजना</span></td><td>उमेद/MSRLM बँक लिंकेज कर्ज नोंदवा, मुदत व बँक हप्ते ट्रॅक करा.</td></tr>
      <tr><td><strong>१३. मासिक नफा-तोटा तपासणे</strong></td><td><span class="btn-tag">१५. नफा-तोटा पत्रक</span></td><td>चालू महिन्याची जमा vs खर्च निव्वळ नफा (Net Surplus) पत्रक तपासा.</td></tr>
      <tr><td><strong>१४. वर्गणी किंवा दंड आकारणे</strong></td><td><span class="btn-tag">१६. वर्गणी व दंड नोंद</span></td><td>बैठक गैरहजर दंड (₹५०), उशीर दंड किंवा वार्षिक उत्सव वर्गणी वसूल करा.</td></tr>
      <tr><td><strong>१५. बैठकीचे ठराव व कागदपत्रे</strong></td><td><span class="btn-tag">१८. ठराव वही व KYC</span></td><td>बैठकीत मंजूर ठराव क्रमांक व इतिवृत्त लिहा; आधार/पॅन कागदपत्रे जोडा.</td></tr>
      <tr><td><strong>१६. महिला प्रशिक्षण व मेळावा</strong></td><td><span class="btn-tag">२० व २१. प्रशिक्षण व उपक्रम</span></td><td>कौशल्य प्रशिक्षण शिबिरे, बचत गट प्रदर्शन व मेळावा माहिती नोंदवा.</td></tr>
      <tr><td><strong>१७. थकबाकी पाहणे व तगादा लावणे</strong></td><td><span class="btn-tag">२२. थकबाकी व वसुली</span></td><td>थकबाकीदार यादी पहा &rarr; सदस्याला <strong>WhatsApp स्मरणपत्र</strong> पाठवा.</td></tr>
      <tr><td><strong>१८. सूचना व देय स्मरणपत्रे</strong></td><td><span class="btn-tag">२३. सूचना व स्मरणपत्रे</span></td><td>कर्ज हप्ता तारीख, आगामी बैठकीचे स्मरणपत्र व सिंक इशारे पहा.</td></tr>
      <tr><td><strong>१९. ३८+ शासकीय अहवाल PDF</strong></td><td><span class="btn-tag">२४. सर्व अहवाल (Reports)</span></td><td>मासिक अहवाल, वार्षिक ताळेबंद, पासबुक निवडून <strong>PDF डाऊनलोड करा</strong>.</td></tr>
      <tr><td><strong>२०. ऑडिट व बदल ट्रॅकिंग</strong></td><td><span class="btn-tag">२५. ऑडिट व हालचाली नोंद</span></td><td>कोणी, कधी कोणती नोंद केली याचा पूर्ण ऑडिट ट्रेल (Audit Log) तपासा.</td></tr>
      <tr><td><strong>२१. गट नियम व पदाधिकारी बदल</strong></td><td><span class="btn-tag">२६. गट माहिती, फोटो व नियम</span></td><td>गट नाव, लोगो, पदाधिकारी फोन नंबर व मासिक बचत नियम अद्ययावत करा.</td></tr>
      <tr><td><strong>२२. संपूर्ण डेटा बॅकअप घेणे (.db)</strong></td><td><span class="btn-tag">२७. बॅकअप व रिस्टोअर (.db)</span></td><td><strong>बॅकअप एक्सपोर्ट</strong> दाबा &rarr; <code>.db</code> फाईल पेनड्राइव्ह किंवा फोनमध्ये सेव्ह करा.</td></tr>
      <tr><td><strong>२३. मोबाईलवर स्क्रीन झूम करणे</strong></td><td><span class="btn-tag">मोबाईल व्ह्यू व झूम टूलबार</span></td><td>दोन बोटांनी पिंच-झूम करा किंवा खालील <strong>झूम टूलबार</strong> वापरा.</td></tr>
    </tbody>
  </table>

  <div class="page-break"></div>

  <!-- भाग २: प्रत्यक्ष स्क्रीन्सचे खरे फोटो व कार्यपद्धती -->
  <div class="section-title">
    <span>भाग २: सर्व २३ मॉड्यूल्सचे प्रत्यक्ष स्क्रीन फोटो व कार्यपद्धती (Actual Screen Photos Guide)</span>
    <span style="font-size: 9.5px; font-weight: normal; color: #6b21a8;">प्रत्यक्ष स्क्रीन फोटो व सविस्तर पायऱ्या</span>
  </div>
"""

# Append each module screen block
for i, m in enumerate(MODULES_DATA):
    steps_html = "\n".join([f"<li>{s}</li>" for s in m["desc"]])
    
    # Add page-break after every screen to ensure clear print rendering
    pb = '<div class="page-break"></div>' if i < len(MODULES_DATA) - 1 else ''
    
    html += f"""
  <!-- SCREEN {m['num']} -->
  <div class="screen-block">
    <div class="screen-block-header">
      <h3>{m['title']}</h3>
      <span class="badge-label {m['badge_cls']}">{m['badge']}</span>
    </div>
    <img src="{m['img']}" class="screen-photo" alt="{m['title']}">
    <div class="steps-box">
      <strong>कसे वापरावे (Operating Steps):</strong>
      <ol>
        {steps_html}
      </ol>
      <div class="tip-box">
        💡 <strong>महत्त्वाची टीप:</strong> {m['tip']}
      </div>
    </div>
  </div>
  {pb}
"""

html += """
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
        <td>स्थानिक संगणक डिस्कवर कायमस्वरूपी सुरक्षित.</td>
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

with open(MANUAL_HTML, "w", encoding="utf-8") as f:
    f.write(html)

print(f"Generated {MANUAL_HTML} with all 23 actual screen photos embedded!")

# Now render to PDF
cmd = [
    CHROME_EXE,
    "--headless=new",
    "--disable-gpu",
    "--no-pdf-header-footer",
    f"--print-to-pdf={PDF_OUT}",
    MANUAL_HTML
]
print("Compiling into PDF...")
subprocess.run(cmd, check=True)
print(f"Successfully compiled {PDF_OUT}!")
