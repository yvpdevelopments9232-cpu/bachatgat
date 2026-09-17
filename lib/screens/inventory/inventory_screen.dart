import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentGroup != null) {
      try {
        final res = await _service.client
            .from('products')
            .select()
            .eq('group_id', auth.currentGroup!.id)
            .order('created_at', ascending: false);
        setState(() {
          _products = List<Map<String, dynamic>>.from(res as List);
        });
      } catch (e) {
        debugPrint('Error loading products: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    final totalStockQty = _products.fold<int>(
      0,
      (sum, p) => sum + (int.tryParse(p['current_stock']?.toString() ?? '0') ?? 0),
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
                            AppStrings.tr('गटाची उत्पादने व विक्री (Products & POS)', 'SHG Products & Sales POS'),
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            AppStrings.tr('पापड, लोणचे, मसाले, हस्तकला व स्टॉक इन/आउट नोंद', 'Papad, Pickles, Spices & Stock Management'),
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      AppButton(
                        icon: Icons.add_box_rounded,
                        text: AppStrings.tr('नवीन उत्पादन जोडा', 'Add Product'),
                        onPressed: () => _showAddProductDialog(context, auth),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Metrics
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppStrings.tr('एकूण उत्पादने', 'Total Product Varieties'), style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Text('${_products.length}', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
                              Text(AppStrings.tr('उपलब्ध एकूण स्टॉक (नग/किलो)', 'Total Available Stock'), style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Text('$totalStockQty', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.success)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    AppStrings.tr('उत्पादने व स्टॉक यादी', 'Product Catalog & Stock'),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  if (_products.isEmpty)
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
                          const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.tr('कोणतेही उत्पादन नोंदवलेले नाही', 'No products listed yet'),
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            text: AppStrings.tr('पहिले उत्पादन नोंदवा', 'Add First Product'),
                            icon: Icons.add,
                            onPressed: () => _showAddProductDialog(context, auth),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        mainAxisExtent: 160,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (ctx, i) {
                        final p = _products[i];
                        final name = p['product_name'] ?? 'उत्पादन';
                        final unit = p['unit'] ?? 'किलो';
                        final price = p['selling_price'] ?? p['unit_price'] ?? 0;
                        final stock = p['current_stock'] ?? 0;

                        return AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.secondary.withOpacity(0.12),
                                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.secondary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('दर: ₹ $price प्रति $unit', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('शिल्लक साठा:', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary)),
                                      Text('$stock $unit', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(Icons.point_of_sale_rounded, size: 14, color: Colors.white),
                                    label: const Text('विक्री (Sell)', style: TextStyle(fontSize: 11, color: Colors.white)),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$name ची विक्री नोंद सुरू! (Sale initiated)')),
                                      );
                                    },
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

  void _showAddProductDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'किलो (kg)');
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('नवीन उत्पादन जोडा', 'Add New Product')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('उत्पादनाचे नाव*', 'Product Name*'),
                  hintText: 'उदा. उडीद पापड / आंबा लोणचे / गरम मसाला',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('किंमत (₹)*', 'Unit Price (₹)*'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: AppStrings.tr('एकक (Unit)*', 'Unit*'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.tr('आरंभीचा साठा (Initial Stock)*', 'Initial Stock*'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final priceVal = double.tryParse(priceCtrl.text) ?? 0.0;
                await _service.client.from('products').insert({
                  'group_id': auth.currentGroup!.id,
                  'product_name': nameCtrl.text.trim(),
                  'unit': unitCtrl.text.trim(),
                  'selling_price': priceVal,
                  'unit_price': priceVal,
                  'current_stock': int.tryParse(stockCtrl.text) ?? 0,
                });
                await _loadProducts();
              } catch (e) {
                debugPrint('Error adding product: $e');
              }
            },
            child: Text(AppStrings.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
