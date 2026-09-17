import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.infoBg;
    Color fg = AppColors.info;
    String text = label ?? status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'verified':
      case 'approved':
      case 'present':
        bg = AppColors.successBg;
        fg = AppColors.success;
        break;
      case 'pending':
      case 'under_review':
      case 'applied':
      case 'scheduled':
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        break;
      case 'overdue':
      case 'rejected':
      case 'absent':
      case 'defaulted':
      case 'inactive':
        bg = AppColors.dangerBg;
        fg = AppColors.danger;
        break;
      case 'disbursed':
      case 'ongoing':
        bg = AppColors.successBg;
        fg = AppColors.success;
        if (label == null) text = 'सक्रिय (ACTIVE)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
