import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class BankLoanScreen extends StatefulWidget {
  const BankLoanScreen({super.key});

  @override
  State<BankLoanScreen> createState() => _BankLoanScreenState();
}

class _BankLoanScreenState extends State<BankLoanScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _bankLoans = [];

  @override
  void initState() {
    super.initState();
    _loadBankLoans();
  }

  Future<void> _loadBankLoans() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      try {
        final res = await _service.client
            .from('bank_loans')
            .select()
            .eq('group_id', auth.currentGroup!.id)
            .order('created_at', ascending: false);
        setState(() {
          _bankLoans = List<Map<String, dynamic>>.from(res as List);
        });
      } catch (e) {
        debugPrint('Error loading bank loans: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final totalLoanAmount = _bankLoans.fold<double>(
      0.0,
      (sum, l) => sum + (double.tryParse(l['loan_amount']?.toString() ?? '0') ?? 0.0),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.tr('बँक कर्ज व सरकारी योजना', 'Bank Loans & Government Schemes'),
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            AppStrings.tr('राष्ट्रीयीकृत व सहकारी बँक कर्ज लिंकेज', 'Nationalized & Cooperative Bank Loan Linkage'),
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      AppButton(
                        icon: Icons.add_rounded,
                        text: AppStrings.tr('नवीन बँक कर्ज नोंद', 'Add Bank Loan'),
                        onPressed: () => _showAddBankLoanDialog(context, auth),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('एकूण बँक कर्ज', 'Total Bank Loan Sanctioned'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₹ ${totalLoanAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('सक्रिय बँक कर्ज खाती', 'Active Bank Loan Accounts'),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_bankLoans.length}',
                                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Schemes info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.secondary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('दीनदयाळ अंत्योदय योजना - NRLM / उमेद योजना', 'Deendayal Antyodaya Yojana - NRLM / UMED Scheme'),
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                              ),
                              Text(
                                AppStrings.tr('महिला बचत गटांना ७% व्याज दराने व वेळेवर परतफेडीवर ३% व्याज परतावा (Subvention) उपलब्ध आहे.', 'SHGs are eligible for 7% interest rate and 3% interest subvention upon timely repayment.'),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loan List
                  Text(
                    AppStrings.tr('बँक कर्जांची यादी', 'Bank Loans List'),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  if (_bankLoans.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.tr('कोणतेही बँक कर्ज नोंदवलेले नाही', 'No bank loans recorded yet'),
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            text: AppStrings.tr('नवीन बँक कर्ज जोडा', 'Add Bank Loan'),
                            icon: Icons.add,
                            onPressed: () => _showAddBankLoanDialog(context, auth),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _bankLoans.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final loan = _bankLoans[i];
                        final bankName = loan['bank_name'] ?? 'Bank';
                        final amount = loan['loan_amount'] ?? 0;
                        final tenure = loan['tenure_months'] ?? 12;
                        final rate = loan['interest_rate'] ?? 7;

                        return AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                radius: 24,
                                child: const Icon(Icons.account_balance_rounded, color: AppColors.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bankName,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    Text(
                                      'खाते क्र: ${loan['account_number'] ?? "N/A"} • कालावधी: $tenure महिने • व्याज: $rate%',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹ $amount',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      loan['status'] ?? 'Active',
                                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  void _showAddBankLoanDialog(BuildContext context, AuthProvider auth) {
    final bankNameCtrl = TextEditingController();
    final accNoCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final tenureCtrl = TextEditingController(text: '24');
    final interestRateCtrl = TextEditingController(text: '7.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('नवीन बँक कर्ज नोंदणी', 'Add New Bank Loan')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankNameCtrl,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('बँकेचे नाव (Bank Name)*', 'Bank Name*'),
                  hintText: 'उदा. बँक ऑफ महाराष्ट्र, SBI',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accNoCtrl,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('कर्ज खाते क्रमांक (Loan Account No.)', 'Loan Account No.'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('कर्ज रक्कम (Loan Amount ₹)*', 'Loan Amount (₹)*'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tenureCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('कालावधी (महिने)*', 'Tenure (Months)*'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: interestRateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('व्याज दर (% वार्षिक)*', 'Interest Rate (%)*'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (bankNameCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _service.client.from('bank_loans').insert({
                  'group_id': auth.currentGroup!.id,
                  'bank_name': bankNameCtrl.text.trim(),
                  'account_number': accNoCtrl.text.trim(),
                  'loan_amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'tenure_months': int.tryParse(tenureCtrl.text) ?? 24,
                  'interest_rate': double.tryParse(interestRateCtrl.text) ?? 7.0,
                  'status': 'active',
                });
                _loadBankLoans();
              } catch (e) {
                debugPrint('Error creating bank loan: $e');
              }
            },
            child: Text(AppStrings.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
