import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color utility
// ─────────────────────────────────────────────────────────────────────────────

/// Converts any Firestore-stored color value to a Flutter [Color].
///
/// Handles three formats:
///   • Native [int]  — stored by Flutter's Color.value (e.g. 4281641043)
///     → `Color(colorValue)` directly.
///   • Decimal [String] — a numeric string like "4281641043"
///     → parsed with [int.tryParse] (base 10) then `Color(parsedInt)`.
///   • Hex [String] — "#1A73E8" or "1A73E8"
///     → '#' stripped, padded to 8 chars with 'FF' prefix if 6 chars,
///        parsed with radix 16.
///
/// Falls back to Google-Blue `Color(0xFF1A73E8)` on null or parse failure.
Color hexOrIntColor(dynamic colorValue) {
  const fallback = Color(0xFF1A73E8);

  if (colorValue == null) return fallback;

  // ── Native int (Color.value stored as Firestore number) ───────
  if (colorValue is int) return Color(colorValue);

  // ── String handling ───────────────────────────────────────────
  if (colorValue is String) {
    if (colorValue.isEmpty) return fallback;

    // Try decimal integer first (e.g. "4281641043")
    final asInt = int.tryParse(colorValue);
    if (asInt != null) return Color(asInt);

    // Otherwise treat as hex string
    final clean = colorValue.startsWith('#')
        ? colorValue.substring(1)
        : colorValue;
    final padded = clean.length == 6 ? 'FF$clean' : clean;
    final value = int.tryParse(padded, radix: 16);
    return value != null ? Color(value) : fallback;
  }

  return fallback;
}



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
