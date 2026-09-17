import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/meeting.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/meeting_service.dart';

class MeetingFormDialog extends StatefulWidget {
  final Meeting? meeting; // If null, creating new meeting; if not null, editing existing
  final VoidCallback onSaved;

  const MeetingFormDialog({
    super.key,
    this.meeting,
    required this.onSaved,
  });

  @override
  State<MeetingFormDialog> createState() => _MeetingFormDialogState();
}

class _MeetingFormDialogState extends State<MeetingFormDialog> {
  final MeetingService _meetingService = MeetingService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _locCtrl;
  late TextEditingController _agendaCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _minutesCtrl;

  String _meetingType = 'monthly';
  String _status = 'scheduled';
  bool _isSaving = false;

  bool get isEditing => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    final now = DateTime.now();

    _dateCtrl = TextEditingController(
      text: m?.meetingDate ?? "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
    );
    _timeCtrl = TextEditingController(text: m?.meetingTime ?? '04:00 PM');
    _locCtrl = TextEditingController(text: m?.location ?? 'अध्यक्षांचे घर / समाज मंदिर');
    _agendaCtrl = TextEditingController(text: m?.agenda ?? 'मासिक बचत जमा व कर्ज हप्ता वसुली');
    _descCtrl = TextEditingController(text: m?.description ?? '');
    _minutesCtrl = TextEditingController(text: m?.minutesOfMeeting ?? '');

    _meetingType = m?.meetingType ?? 'monthly';
    _status = m?.status ?? 'scheduled';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _locCtrl.dispose();
    _agendaCtrl.dispose();
    _descCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initDate = DateTime.tryParse(_dateCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'बैठक तारीख निवडा (Meeting Date)',
    );
    if (picked != null) {
      setState(() {
        _dateCtrl.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final min = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        _timeCtrl.text = "${hour.toString().padLeft(2, '0')}:$min $period";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 560,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Close ('X') Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_calendar_rounded : Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'बैठक संपादन करा' : 'नवीन बैठक आयोजित करा',
                                  style: GoogleFonts.poppins(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isEditing ? 'बैठकीची तारीख, वेळ, अजेंडा अपडेट करा' : 'मासिक किंवा विशेष बैठकीची नोंद करा',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 24),
                      tooltip: 'बंद करा (Close)',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Meeting Date & Time Row
                Row(
                  children: [
                    // Date
                    Expanded(
                      child: TextFormField(
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: InputDecoration(
                          labelText: 'बैठक तारीख (Date)*',
                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'तारीख आवश्यक आहे' : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Time
                    Expanded(
                      child: TextFormField(
                        controller: _timeCtrl,
                        readOnly: true,
                        onTap: _pickTime,
                        decoration: InputDecoration(
                          labelText: 'बैठक वेळ (Time)*',
                          prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'वेळ आवश्यक आहे' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Location
                TextFormField(
                  controller: _locCtrl,
                  decoration: InputDecoration(
                    labelText: 'बैठक ठिकाण (Meeting Location)*',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'ठिकाण आवश्यक आहे' : null,
                ),
                const SizedBox(height: 14),

                // Meeting Type & Status Row
                Row(
                  children: [
                    // Meeting Type
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _meetingType,
                        decoration: InputDecoration(
                          labelText: 'बैठक प्रकार (Type)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'monthly', child: Text('मासिक बैठक (Monthly)')),
                          DropdownMenuItem(value: 'special', child: Text('विशेष बैठक (Special)')),
                          DropdownMenuItem(value: 'emergency', child: Text('तातडीची बैठक (Emergency)')),
                          DropdownMenuItem(value: 'annual', child: Text('वार्षिक बैठक (Annual AGM)')),
                        ],
                        onChanged: (v) => setState(() => _meetingType = v ?? 'monthly'),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: InputDecoration(
                          labelText: 'स्थिती (Status)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'scheduled', child: Text('नियोजित (Scheduled)')),
                          DropdownMenuItem(value: 'completed', child: Text('पूर्ण झाली (Completed)')),
                          DropdownMenuItem(value: 'cancelled', child: Text('रद्द (Cancelled)')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Agenda
                TextFormField(
                  controller: _agendaCtrl,
                  decoration: InputDecoration(
                    labelText: 'विषयसूची / अजेंडा (Meeting Agenda)*',
                    prefixIcon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'अजेंडा आवश्यक आहे' : null,
                ),
                const SizedBox(height: 14),

                // Resolutions / Notes
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'ठराव / विषय चर्चा (Discussion / Resolutions)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Minutes of Meeting
                TextFormField(
                  controller: _minutesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'बैठकीचे इतिवृत्त (Minutes of Meeting)',
                    hintText: 'उदा. सर्व सदस्यांच्या अनुमतीने नवीन नियम मंजूर करण्यात आले.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(AppStrings.cancel, style: const TextStyle(color: Colors.black87)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      label: Text(
                        _isSaving ? 'जतन होत आहे...' : (isEditing ? 'बदल जतन करा (Update)' : 'बैठक नोंदवा (Save)'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groupId = auth.currentGroup?.id;
    if (groupId == null) return;

    setState(() => _isSaving = true);

    bool ok = false;
    if (isEditing) {
      final updated = Meeting(
        id: widget.meeting!.id,
        groupId: groupId,
        meetingDate: _dateCtrl.text.trim(),
        meetingTime: _timeCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        meetingType: _meetingType,
        agenda: _agendaCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        minutesOfMeeting: _minutesCtrl.text.trim(),
        status: _status,
      );
      ok = await _meetingService.updateMeeting(updated);
    } else {
      final newMeeting = Meeting(
        id: '',
        groupId: groupId,
        meetingDate: _dateCtrl.text.trim(),
        meetingTime: _timeCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        meetingType: _meetingType,
        agenda: _agendaCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        minutesOfMeeting: _minutesCtrl.text.trim(),
        status: _status,
      );
      final created = await _meetingService.createMeeting(newMeeting);
      ok = created != null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'बैठक माहिती यशस्वीरीत्या अद्ययावत झाली!' : 'नवीन बैठक यशस्वीरीत्या नोंदवली गेली!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('बैठक जतन करताना त्रुटी आली. कृपया पुन्हा प्रयत्न करा.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
