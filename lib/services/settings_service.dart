import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'admin_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsService
//
// Persists application settings to the `system_settings` Supabase table
// (singleton row with id = 'singleton').
//
// Falls back to in-memory defaults when Supabase is not reachable.
// ─────────────────────────────────────────────────────────────────────────────

class AppSettings {
  final String appName;
  final String language;
  final String dateFormat;
  final String timeZone;
  final String currency;
  final bool notifCampaigns;
  final bool notifLeads;
  final bool notifBudget;
  final bool notifReports;
  final bool notifSystem;

  const AppSettings({
    this.appName        = 'MarketFlow',
    this.language       = 'English',
    this.dateFormat     = 'DD/MM/YYYY',
    this.timeZone       = 'Africa/Addis_Ababa',
    this.currency       = 'ETB',
    this.notifCampaigns = true,
    this.notifLeads     = true,
    this.notifBudget    = true,
    this.notifReports   = true,
    this.notifSystem    = true,
  });

  AppSettings copyWith({
    String? appName, String? language, String? dateFormat,
    String? timeZone, String? currency,
    bool? notifCampaigns, bool? notifLeads, bool? notifBudget,
    bool? notifReports, bool? notifSystem,
  }) =>
      AppSettings(
        appName:        appName        ?? this.appName,
        language:       language       ?? this.language,
        dateFormat:     dateFormat     ?? this.dateFormat,
        timeZone:       timeZone       ?? this.timeZone,
        currency:       currency       ?? this.currency,
        notifCampaigns: notifCampaigns ?? this.notifCampaigns,
        notifLeads:     notifLeads     ?? this.notifLeads,
        notifBudget:    notifBudget    ?? this.notifBudget,
        notifReports:   notifReports   ?? this.notifReports,
        notifSystem:    notifSystem    ?? this.notifSystem,
      );

  Map<String, dynamic> toRow() => {
        'id':              'singleton',
        'app_name':        appName,
        'language':        language,
        'date_format':     dateFormat,
        'time_zone':       timeZone,
        'currency':        currency,
        'notif_campaigns': notifCampaigns,
        'notif_leads':     notifLeads,
        'notif_budget':    notifBudget,
        'notif_reports':   notifReports,
        'notif_system':    notifSystem,
        'updated_at':      DateTime.now().toIso8601String(),
      };

  static AppSettings fromRow(Map<String, dynamic> r) => AppSettings(
        appName:        r['app_name']?.toString()  ?? 'MarketFlow',
        language:       r['language']?.toString()  ?? 'English',
        dateFormat:     r['date_format']?.toString() ?? 'DD/MM/YYYY',
        timeZone:       r['time_zone']?.toString() ?? 'Africa/Addis_Ababa',
        currency:       r['currency']?.toString()  ?? 'ETB',
        notifCampaigns: r['notif_campaigns'] == true,
        notifLeads:     r['notif_leads']     == true,
        notifBudget:    r['notif_budget']    == true,
        notifReports:   r['notif_reports']   == true,
        notifSystem:    r['notif_system']    == true,
      );
}

class SettingsService {
  SettingsService._();

  static const _table = 'system_settings';
  static AppSettings _current = const AppSettings();
  static bool _loaded = false;

  static AppSettings get current => _current;

  /// Load settings from Supabase. Call once at startup after auth.
  static Future<void> load() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .eq('id', 'singleton')
          .limit(1)
          .timeout(const Duration(seconds: 6));
      if (rows.isNotEmpty) {
        _current = AppSettings.fromRow(rows.first);
        _loaded = true;
      }
    } catch (e) {
      developer.log('SettingsService.load failed: $e', name: 'SettingsService');
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'read', error: e);
    }
  }

  /// Persist updated settings to Supabase.
  static Future<bool> save(AppSettings settings) async {
    _current = settings;
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(settings.toRow())
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      developer.log('SettingsService.save failed: $e', name: 'SettingsService');
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
      return false;
    }
  }

  static bool get isLoaded => _loaded;
}
