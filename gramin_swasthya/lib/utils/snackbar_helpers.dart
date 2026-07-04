import 'package:flutter/material.dart';

/// Shows a success SnackBar with a Material check icon.
///
/// Replaces the old check-mark emoji that used to be embedded in success
/// messages so the app uses Google Material icons consistently instead of emoji.
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
