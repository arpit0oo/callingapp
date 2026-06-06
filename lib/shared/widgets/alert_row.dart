import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single alert row: amber warning icon + [message] + [timeAgo] timestamp.
class AlertRow extends StatelessWidget {
  const AlertRow({
    super.key,
    required this.message,
    required this.timeAgo,
  });

  final String message;
  final String timeAgo;

  static const _kYellow = Color(0xFFFBBC04);
  static const _kGrey = Color(0xFF80868B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: _kYellow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF202124),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
