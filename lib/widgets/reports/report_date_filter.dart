import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportDateFilter extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final Function(DateTime fromDate, DateTime toDate) onApply;
  final VoidCallback onReset;
  final bool showPresets;

  const ReportDateFilter({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    required this.onApply,
    required this.onReset,
    this.showPresets = true,
  });

  @override
  State<ReportDateFilter> createState() => _ReportDateFilterState();
}

class _ReportDateFilterState extends State<ReportDateFilter> {
  late DateTime _fromDate;
  late DateTime _toDate;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
  }

  @override
  void didUpdateWidget(covariant ReportDateFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFromDate != widget.initialFromDate ||
        oldWidget.initialToDate != widget.initialToDate) {
      _fromDate = widget.initialFromDate;
      _toDate = widget.initialToDate;
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'आरंभीची तारीख निवडा (Select From Date)',
      cancelText: 'रद्द करा',
      confirmText: 'निवडा',
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _selectedPreset = null;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'शेवटची तारीख निवडा (Select To Date)',
      cancelText: 'रद्द करा',
      confirmText: 'निवडा',
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _selectedPreset = null;
      });
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      if (preset == 'this_month') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = DateTime(now.year, now.month + 1, 0);
      } else if (preset == 'last_month') {
        _fromDate = DateTime(now.year, now.month - 1, 1);
        _toDate = DateTime(now.year, now.month, 0);
      } else if (preset == 'this_year') {
        if (now.month >= 4) {
          _fromDate = DateTime(now.year, 4, 1);
          _toDate = DateTime(now.year + 1, 3, 31);
        } else {
          _fromDate = DateTime(now.year - 1, 4, 1);
          _toDate = DateTime(now.year, 3, 31);
        }
      } else if (preset == 'all_time') {
        _fromDate = DateTime(now.year - 5, 1, 1);
        _toDate = DateTime(now.year, 12, 31);
      }
    });
    _handleApply();
  }

  void _handleApply() {
    if (_fromDate.isAfter(_toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ आरंभीची तारीख (From Date) ही शेवटच्या तारखेपेक्षा (To Date) नंतरची असू शकत नाही!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onApply(_fromDate, _toDate);
  }

  void _handleReset() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month + 1, 0);
      _selectedPreset = 'this_month';
    });
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.date_range_rounded, color: Colors.indigo, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'तारीख फिल्टर (Universal Date Filter)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ' - ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets
          if (widget.showPresets) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('चालू महिना (This Month)', 'this_month'),
                  const SizedBox(width: 8),
                  _buildPresetChip('मागील महिना (Last Month)', 'last_month'),
                  const SizedBox(width: 8),
                  _buildPresetChip('आर्थिक वर्ष (FY)', 'this_year'),
                  const SizedBox(width: 8),
                  _buildPresetChip('सर्व कालावधी (All)', 'all_time'),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Date pickers & Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'From Date (पासून)',
                            date: _fromDate,
                            onTap: () => _selectFromDate(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDateField(
                            label: 'To Date (पर्यंत)',
                            date: _toDate,
                            onTap: () => _selectToDate(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleApply,
                            icon: const Icon(Icons.filter_alt_rounded, size: 18),
                            label: const Text('लागू करा (Apply)', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _handleReset,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('रीसेट'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildDateField(
                      label: 'From Date (पासून)',
                      date: _fromDate,
                      onTap: () => _selectFromDate(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _buildDateField(
                      label: 'To Date (पर्यंत)',
                      date: _toDate,
                      onTap: () => _selectToDate(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleApply,
                    icon: const Icon(Icons.filter_alt_rounded, size: 18),
                    label: const Text('APPLY FILTER', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _handleReset,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('RESET'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String key) {
    final isSelected = _selectedPreset == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => _applyPreset(key),
      selectedColor: Colors.indigo.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.indigo.shade900 : Colors.grey.shade800,
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: Colors.indigo.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFormat.format(date),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
