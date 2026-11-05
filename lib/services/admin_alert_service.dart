// ─────────────────────────────────────────────────────────────────────────────
// AdminAlertService
//
// Fire-and-forget reporting of notable events to the MarkFlow backend, which
// emails them to the admin mailbox via POST /api/alerts.
//
// Two kinds of events are reported:
//   • errors   — failed Supabase reads/writes, uncaught Flutter errors
//   • events   — key milestones (campaign created/deleted, new lead,
//                budget crossing its 80% spend threshold)
//
// Everything here is best effort: a missing backend, no network or a slow
// server must never interfere with the app, so nothing is awaited by callers
// and every failure is swallowed (and only logged at debug level).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import 'persistence_feedback.dart';

class AdminAlertService {
  AdminAlertService._();

  static const String _logName = 'AdminAlert';
  static const Duration _timeout = Duration(seconds: 4);

  /// True when reporting is configured (see [BackendConfig]).
  static bool get isEnabled => BackendConfig.alertsConfigured;

  /// Reports [message] under [event]. Never throws, never awaits.
  ///
  /// [severity] is one of `info`, `warning`, `error`.
  static void report({
    required String event,
    required String message,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) {
    if (!isEnabled) return;

    final body = <String, dynamic>{
      'event': event,
      'message': message,
      'severity': severity,
      'source': 'flutter',
      if (details != null && details.isNotEmpty) 'details': details,
    };

    final uri = Uri.parse('${BackendConfig.normalizedUrl}/api/alerts');
    unawaited(_post(uri, body));
  }

  /// Convenience wrapper used by the Supabase remote stores.
  static void reportStoreFailure({
    required String table,
    required String operation,
    required Object error,
  }) {
    PersistenceFeedback.reportFailure(
      table: table,
      operation: operation,
      error: error,
    );
    report(
      event: 'Database $operation failed',
      message: 'Supabase $operation on "$table" failed: $error',
      severity: 'error',
      details: {
        'table': table,
        'operation': operation,
        'error': error.toString(),
      },
    );
  }

  static Future<void> _post(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Alert-Token': BackendConfig.alertToken,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      // 503 = backend up but email alerts not configured on the server side.
      if (res.statusCode >= 400 && res.statusCode != 503) {
        developer.log(
          'Alert not delivered (HTTP ${res.statusCode}): ${res.body}',
          name: _logName,
          level: 900,
        );
      }
    } catch (e) {
      // Backend offline is normal while developing — stay quiet.
      developer.log('Could not reach backend: $e', name: _logName, level: 500);
    }
  }
}
