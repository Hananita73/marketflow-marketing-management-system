import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../core/colors.dart';

class PersistenceFeedback {
  PersistenceFeedback._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void reportFailure({
    required String table,
    required String operation,
    required Object error,
  }) {
    final errorMessage = error.toString();
    final detail = errorMessage.length > 180
        ? '${errorMessage.substring(0, 177)}...'
        : errorMessage;
    developer.log(
      'Supabase $operation failed for $table: $errorMessage',
      name: 'Persistence',
      error: error,
    );

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Could not $operation $table: $detail'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
