import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class CallData {
  const CallData({
    required this.time,
    required this.number,
    required this.disposition,
    required this.chipBg,
    required this.chipFg,
    required this.duration,
  });

  final String time;
  final String number;
  final String disposition;
  final Color chipBg;
  final Color chipFg;
  final String duration;
}

// ─────────────────────────────────────────────────────────────────────────────
// Row widget
// ─────────────────────────────────────────────────────────────────────────────

class RecentCallRow extends StatelessWidget {
  const RecentCallRow({super.key, required this.call});
  final CallData call;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Time
          Text(
            call.time,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9AA0A6),
            ),
          ),
          const SizedBox(width: 10),
          // Phone number
          Expanded(
            child: Text(
              call.number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF202124),
              ),
            ),
          ),
          // Duration
          if (call.duration.isNotEmpty) ...[
            Text(
              call.duration,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Disposition chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: call.chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              call.disposition,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: call.chipFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
