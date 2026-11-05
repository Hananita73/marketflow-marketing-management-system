import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/theme_notifier.dart';
import '../../services/settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// ── In-memory settings state ──────────────────────────────────────────────────

class _SettingsState {
  // General
  String appName = 'MarketFlow';
  String appDescription = 'All-in-one marketing management platform';
  String language = 'English';
  String dateFormat = 'DD/MM/YYYY';
  String timeZone = 'Africa/Addis_Ababa (EAT, UTC+3)';

  // Appearance
  String theme = 'Light';
  bool compactMode = false;
  String sidebarBehavior = 'Always visible';
  String density = 'Comfortable';

  // Notifications
  bool enableNotifications = true;
  bool emailNotifications = true;
  bool campaignNotifications = true;
  bool leadNotifications = true;
  bool customerNotifications = false;
  bool budgetAlerts = true;
  bool automationAlerts = true;
  bool reportNotifications = false;

  // Security
  bool twoFactor = false;
  bool loginAlerts = true;
  String lastPasswordChange = 'June 3, 2026';

  // Privacy
  bool profileVisibility = true;
  bool activityVisibility = false;
  bool dataPreferences = true;
  bool analyticsPreferences = true;

  // App Preferences
  String defaultLandingPage = 'Dashboard';
  String timeFormat = '24-hour';
  int defaultTableRows = 10;
  bool autoRefresh = false;

  _SettingsState clone() {
    final s = _SettingsState();
    s.appName = appName;
    s.appDescription = appDescription;
    s.language = language;
    s.dateFormat = dateFormat;
    s.timeZone = timeZone;
    s.theme = theme;
    s.compactMode = compactMode;
    s.sidebarBehavior = sidebarBehavior;
    s.density = density;
    s.enableNotifications = enableNotifications;
    s.emailNotifications = emailNotifications;
    s.campaignNotifications = campaignNotifications;
    s.leadNotifications = leadNotifications;
    s.customerNotifications = customerNotifications;
    s.budgetAlerts = budgetAlerts;
    s.automationAlerts = automationAlerts;
    s.reportNotifications = reportNotifications;
    s.twoFactor = twoFactor;
    s.loginAlerts = loginAlerts;
    s.lastPasswordChange = lastPasswordChange;
    s.profileVisibility = profileVisibility;
    s.activityVisibility = activityVisibility;
    s.dataPreferences = dataPreferences;
    s.analyticsPreferences = analyticsPreferences;
    s.defaultLandingPage = defaultLandingPage;
    s.timeFormat = timeFormat;
    s.defaultTableRows = defaultTableRows;
    s.autoRefresh = autoRefresh;
    return s;
  }
}

// ── Section IDs ───────────────────────────────────────────────────────────────

const List<_SectionMeta> _kSections = [
  _SectionMeta('general',      'General',                  Icons.tune_outlined),
  _SectionMeta('appearance',   'Appearance',               Icons.palette_outlined),
  _SectionMeta('notifications','Notifications',            Icons.notifications_outlined),
  _SectionMeta('security',     'Security',                 Icons.lock_outline),
  _SectionMeta('privacy',      'Privacy',                  Icons.privacy_tip_outlined),
  _SectionMeta('preferences',  'Application Preferences',  Icons.apps_outlined),
];

class _SectionMeta {
  final String id;
  final String label;
  final IconData icon;
  const _SectionMeta(this.id, this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsScreenState
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsScreenState extends State<SettingsScreen> {
  String _activeSection = 'general';
  late _SettingsState _current;
  late _SettingsState _saved;
  bool get _isDirty => _dirtyCheck();

  ThemeNotifier? _themeNotifier;

  @override
  void initState() {
    super.initState();
    _current = _SettingsState();
    _saved   = _current.clone();
    // Load persisted settings and apply them
    _loadPersistedSettings();
  }

  Future<void> _loadPersistedSettings() async {
    await SettingsService.load();
    if (!mounted) return;
    final s = SettingsService.current;
    setState(() {
      _current.appName            = s.appName;
      _current.language           = s.language;
      _current.dateFormat         = s.dateFormat;
      _current.timeZone           = s.timeZone;
      _current.campaignNotifications = s.notifCampaigns;
      _current.leadNotifications  = s.notifLeads;
      _current.budgetAlerts       = s.notifBudget;
      _current.reportNotifications = s.notifReports;
      _current.enableNotifications = s.notifSystem;
      _saved = _current.clone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = ThemeNotifier.of(context);
    if (_themeNotifier != notifier) {
      _themeNotifier?.removeListener(_onThemeChanged);
      _themeNotifier = notifier;
      _themeNotifier!.addListener(_onThemeChanged);
    }
    _syncThemeLabel(notifier.mode);
  }

  @override
  void dispose() {
    _themeNotifier?.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (_themeNotifier == null) return;
    setState(() => _syncThemeLabel(_themeNotifier!.mode));
  }

  void _syncThemeLabel(ThemeMode mode) {
    final label = mode == ThemeMode.dark
        ? 'Dark'
        : mode == ThemeMode.system
            ? 'System'
            : 'Light';
    _current.theme = label;
    _saved.theme   = label;
  }

  bool _dirtyCheck() {
    return _current.appName != _saved.appName ||
        _current.appDescription != _saved.appDescription ||
        _current.language != _saved.language ||
        _current.dateFormat != _saved.dateFormat ||
        _current.timeZone != _saved.timeZone ||
        _current.theme != _saved.theme ||
        _current.compactMode != _saved.compactMode ||
        _current.sidebarBehavior != _saved.sidebarBehavior ||
        _current.density != _saved.density ||
        _current.enableNotifications != _saved.enableNotifications ||
        _current.emailNotifications != _saved.emailNotifications ||
        _current.campaignNotifications != _saved.campaignNotifications ||
        _current.leadNotifications != _saved.leadNotifications ||
        _current.customerNotifications != _saved.customerNotifications ||
        _current.budgetAlerts != _saved.budgetAlerts ||
        _current.automationAlerts != _saved.automationAlerts ||
        _current.reportNotifications != _saved.reportNotifications ||
        _current.twoFactor != _saved.twoFactor ||
        _current.loginAlerts != _saved.loginAlerts ||
        _current.profileVisibility != _saved.profileVisibility ||
        _current.activityVisibility != _saved.activityVisibility ||
        _current.dataPreferences != _saved.dataPreferences ||
        _current.analyticsPreferences != _saved.analyticsPreferences ||
        _current.defaultLandingPage != _saved.defaultLandingPage ||
        _current.timeFormat != _saved.timeFormat ||
        _current.defaultTableRows != _saved.defaultTableRows ||
        _current.autoRefresh != _saved.autoRefresh;
  }

  void _save() {
    setState(() => _saved = _current.clone());
    _applyTheme(_current.theme);
    // Persist to Supabase (fire-and-forget)
    SettingsService.save(AppSettings(
      appName:        _current.appName,
      language:       _current.language,
      dateFormat:     _current.dateFormat,
      timeZone:       _current.timeZone,
      notifCampaigns: _current.campaignNotifications,
      notifLeads:     _current.leadNotifications,
      notifBudget:    _current.budgetAlerts,
      notifReports:   _current.reportNotifications,
      notifSystem:    _current.enableNotifications,
    ));
    _snack('Settings saved successfully', isSuccess: true);
  }

  void _applyTheme(String themeLabel) {
    final notifier = ThemeNotifier.of(context);
    switch (themeLabel) {
      case 'Dark':
        notifier.setMode(ThemeMode.dark);
      case 'System':
        notifier.setMode(ThemeMode.system);
      default:
        notifier.setMode(ThemeMode.light);
    }
  }

  void _discard() {
    setState(() => _current = _saved.clone());
    _applyTheme(_saved.theme);
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => _ResetConfirmDialog(
        onConfirm: () {
          setState(() {
            _current = _SettingsState();
            _saved   = _current.clone();
          });
          _snack('Settings reset to defaults');
        },
      ),
    );
  }

  void _snack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: isSuccess ? AppColors.success : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
    );
  }

  void _openChangePassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePasswordDialog(
        onSaved: () => _snack('Password updated successfully', isSuccess: true),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  // Uses CustomScrollView so the page header can be pinned with a
  // SliverPersistentHeader while the body content scrolls normally.

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor    = AppTheme.backgroundFill(brightness);

    return CustomScrollView(
      slivers: [
        // ── Pinned page header ──────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _SettingsHeaderDelegate(
            brightness: brightness,
            bgColor: bgColor,
            onSave: _save,
            onReset: _confirmReset,
            isDirty: _isDirty,
            onSaveBanner: _save,
            onDiscard: _discard,
            isNarrow: MediaQuery.of(context).size.width < 640,
          ),
        ),

        // ── Scrollable body ─────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.itemSpacing,
            AppConstants.pagePadding,
            AppConstants.pagePadding,
          ),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint - 200;
              final isTablet  = constraints.maxWidth >= AppConstants.mobileBreakpoint;

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _SettingsNav(
                        sections: _kSections,
                        active: _activeSection,
                        onSelect: (id) => setState(() => _activeSection = id),
                      ),
                    ),
                    const SizedBox(width: AppConstants.sectionSpacing),
                    Expanded(child: _SectionContent(
                      section: _activeSection,
                      s: _current,
                      onChanged: () => setState(() {}),
                      onChangePassword: _openChangePassword,
                    )),
                  ],
                );
              }

              if (isTablet) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsNav(
                      sections: _kSections,
                      active: _activeSection,
                      onSelect: (id) => setState(() => _activeSection = id),
                      horizontal: true,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    _SectionContent(
                      section: _activeSection,
                      s: _current,
                      onChanged: () => setState(() {}),
                      onChangePassword: _openChangePassword,
                    ),
                  ],
                );
              }

              // Mobile
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MobileNavDropdown(
                    sections: _kSections,
                    active: _activeSection,
                    onSelect: (id) => setState(() => _activeSection = id),
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),
                  _SectionContent(
                    section: _activeSection,
                    s: _current,
                    onChanged: () => setState(() {}),
                    onChangePassword: _openChangePassword,
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsHeaderDelegate  — SliverPersistentHeader delegate for the pinned header
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Brightness brightness;
  final Color bgColor;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final bool isDirty;
  final VoidCallback onSaveBanner;
  final VoidCallback onDiscard;
  final bool isNarrow;

  const _SettingsHeaderDelegate({
    required this.brightness,
    required this.bgColor,
    required this.onSave,
    required this.onReset,
    required this.isDirty,
    required this.onSaveBanner,
    required this.onDiscard,
    required this.isNarrow,
  });

  // Narrow header needs more room for the stacked title + buttons layout.
  static const double _headerWide   = 88.0;
  static const double _headerNarrow = 124.0;
  static const double _bannerExtra  = 8.0 + 52.0; // gap + banner height

  double get _headerHeight => isNarrow ? _headerNarrow : _headerWide;

  @override
  double get minExtent => _headerHeight;

  @override
  double get maxExtent => isDirty ? _headerHeight + _bannerExtra : _headerHeight;

  @override
  bool shouldRebuild(_SettingsHeaderDelegate old) =>
      old.brightness != brightness ||
      old.isDirty != isDirty ||
      old.isNarrow != isNarrow ||
      old.bgColor != bgColor;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final borderColor = AppTheme.border(brightness);

    return Container(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider at bottom when scrolled under content
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                0,
              ),
              child: _SettingsHeader(onSave: onSave, onReset: onReset),
            ),
          ),
          if (isDirty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.pagePadding),
              child: _UnsavedBanner(
                  onSave: onSaveBanner, onDiscard: onDiscard),
            ),
          ],
          Divider(
            height: 1,
            thickness: 1,
            color: overlapsContent ? borderColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onReset;
  const _SettingsHeader({required this.onSave, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textSec     = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (_, constraints) {
      final narrow = constraints.maxWidth < 640;
      final titleBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 4, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text('Settings',
                  style: Theme.of(context).textTheme.displaySmall,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Manage your MarketFlow application preferences and account settings.',
              style: TextStyle(color: textSec, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
      final actions = Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_outlined, size: 16),
          label: const Text('Reset to Default'),
        ),
        ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ]);
      if (narrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          titleBlock,
          const SizedBox(height: 12),
          actions,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        actions,
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UnsavedBanner
// ─────────────────────────────────────────────────────────────────────────────

class _UnsavedBanner extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  const _UnsavedBanner({required this.onSave, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final warnBg  = AppTheme.warningBg(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: warnBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.edit_note_outlined, size: 18, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text('You have unsaved changes.',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary)),
        ),
        TextButton(
          onPressed: onDiscard,
          child: Text('Discard',
              style: TextStyle(fontSize: 13,
                  color: AppTheme.textSecondary(brightness))),
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
          child: const Text('Save Changes', style: TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsNav  — left sidebar (desktop) or horizontal scrollable (tablet)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsNav extends StatelessWidget {
  final List<_SectionMeta> sections;
  final String active;
  final ValueChanged<String> onSelect;
  final bool horizontal;

  const _SettingsNav({
    required this.sections,
    required this.active,
    required this.onSelect,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final borderColor = AppTheme.border(brightness);
    final divColor    = AppTheme.divider(brightness);

    if (horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sections.map((s) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _NavPill(meta: s, isActive: active == s.id,
                  onTap: () => onSelect(s.id)),
            );
          }).toList(),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: List.generate(sections.length, (i) {
          final s = sections[i];
          final isLast = i == sections.length - 1;
          return Column(children: [
            _NavListTile(
              meta: s,
              isActive: active == s.id,
              onTap: () => onSelect(s.id),
            ),
            if (!isLast)
              Divider(height: 1, thickness: 1, color: divColor),
          ]);
        }),
      ),
    );
  }
}

class _NavListTile extends StatefulWidget {
  final _SectionMeta meta;
  final bool isActive;
  final VoidCallback onTap;
  const _NavListTile(
      {required this.meta, required this.isActive, required this.onTap});
  @override
  State<_NavListTile> createState() => _NavListTileState();
}

class _NavListTileState extends State<_NavListTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final active      = widget.isActive;
    final brightness  = Theme.of(context).brightness;
    final activeBg    = AppTheme.primaryLighter(brightness);
    final hoverBg     = AppTheme.surfaceVariant(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? activeBg
                : _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Row(children: [
            Icon(widget.meta.icon,
                size: 18,
                color: active ? AppColors.primary : textSec),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.meta.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.primary : textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active)
              const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}

class _NavPill extends StatefulWidget {
  final _SectionMeta meta;
  final bool isActive;
  final VoidCallback onTap;
  const _NavPill(
      {required this.meta, required this.isActive, required this.onTap});
  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final activeLighter = AppTheme.primaryLighter(brightness);
    final borderColor = AppTheme.border(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primary
                : _hovered ? activeLighter : surfColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: widget.isActive ? AppColors.primary : borderColor,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.meta.icon,
                size: 15,
                color: widget.isActive ? Colors.white : textSec),
            const SizedBox(width: 6),
            Text(widget.meta.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive ? Colors.white : textPrimary,
                )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MobileNavDropdown
// ─────────────────────────────────────────────────────────────────────────────

class _MobileNavDropdown extends StatelessWidget {
  final List<_SectionMeta> sections;
  final String active;
  final ValueChanged<String> onSelect;
  const _MobileNavDropdown(
      {required this.sections, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final borderColor = AppTheme.border(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final meta        = sections.firstWhere((s) => s.id == active);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: active,
          isExpanded: true,
          dropdownColor: surfColor,
          icon: Icon(Icons.keyboard_arrow_down, color: textSec),
          style: TextStyle(
              fontSize: 13,
              color: textPrimary,
              fontWeight: FontWeight.w500),
          items: sections
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Row(children: [
                      Icon(s.icon, size: 16, color: textSec),
                      const SizedBox(width: 8),
                      Text(s.label, style: TextStyle(color: textPrimary)),
                    ]),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onSelect(v); },
          selectedItemBuilder: (_) => sections
              .map((s) => Row(children: [
                    Icon(meta.icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(meta.label,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionContent
// ─────────────────────────────────────────────────────────────────────────────

class _SectionContent extends StatelessWidget {
  final String section;
  final _SettingsState s;
  final VoidCallback onChanged;
  final VoidCallback onChangePassword;

  const _SectionContent({
    required this.section,
    required this.s,
    required this.onChanged,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case 'general':
        return _GeneralSection(s: s, onChanged: onChanged);
      case 'appearance':
        return _AppearanceSection(s: s, onChanged: onChanged);
      case 'notifications':
        return _NotificationsSection(s: s, onChanged: onChanged);
      case 'security':
        return _SecuritySection(
            s: s, onChanged: onChanged, onChangePassword: onChangePassword);
      case 'privacy':
        return _PrivacySection(s: s, onChanged: onChanged);
      case 'preferences':
        return _AppPreferencesSection(s: s, onChanged: onChanged);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsCard — theme-aware card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final borderColor = AppTheme.border(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets — all theme-aware via BuildContext
// ─────────────────────────────────────────────────────────────────────────────

// Section heading row with accent bar
Widget _sectionHeading(BuildContext context, String label, IconData icon) {
  final brightness  = Theme.of(context).brightness;
  final textPrimary = AppTheme.textPrimary(brightness);

  return Row(children: [
    Container(
      width: 4, height: 18,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    const SizedBox(width: 8),
    Icon(icon, size: 18, color: AppColors.primary),
    const SizedBox(width: 8),
    Text(label,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary)),
  ]);
}

// Labeled text field
Widget _labeledField(
  BuildContext context, {
  required String label,
  required String value,
  required ValueChanged<String> onChanged,
  int maxLines = 1,
}) {
  final brightness  = Theme.of(context).brightness;
  final textPrimary = AppTheme.textPrimary(brightness);
  final textSec     = AppTheme.textSecondary(brightness);
  final inputFill   = AppTheme.inputFill(brightness);
  final borderColor = AppTheme.border(brightness);

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textPrimary)),
    const SizedBox(height: 6),
    TextFormField(
      initialValue: value,
      maxLines: maxLines,
      style: TextStyle(fontSize: 13, color: textPrimary),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: textSec, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: onChanged,
    ),
  ]);
}

// Labeled dropdown — theme-aware
Widget _labeledDropdown<T>(
  BuildContext context, {
  required String label,
  required T value,
  required List<T> items,
  required ValueChanged<T?> onChanged,
  String Function(T)? display,
}) {
  final brightness  = Theme.of(context).brightness;
  final textPrimary = AppTheme.textPrimary(brightness);
  final textSec     = AppTheme.textSecondary(brightness);
  final inputFill   = AppTheme.inputFill(brightness);
  final borderColor = AppTheme.border(brightness);

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textPrimary)),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceColor(brightness),
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textSec),
          style: TextStyle(fontSize: 13, color: textPrimary),
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text(
                      display != null ? display(i) : i.toString(),
                      style: TextStyle(color: textPrimary),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    ),
  ]);
}

// Toggle row with label + description — theme-aware
Widget _switchRow(
  BuildContext context, {
  required String label,
  String? description,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final brightness  = Theme.of(context).brightness;
  final textPrimary = AppTheme.textPrimary(brightness);
  final textSec     = AppTheme.textSecondary(brightness);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary)),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(description,
                style: TextStyle(fontSize: 12, color: textSec)),
          ],
        ]),
      ),
      const SizedBox(width: 12),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 1 — General
// ─────────────────────────────────────────────────────────────────────────────

class _GeneralSection extends StatelessWidget {
  final _SettingsState s;
  final VoidCallback onChanged;
  const _GeneralSection({required this.s, required this.onChanged});

  static const List<String> _languages   = ['English', 'Amharic'];
  static const List<String> _dateFormats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];
  static const List<String> _timeZones   = [
    'Africa/Addis_Ababa (EAT, UTC+3)',
    'UTC',
    'America/New_York (EST, UTC-5)',
    'Europe/London (GMT, UTC+0)',
    'Asia/Dubai (GST, UTC+4)',
  ];

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading(context, 'General', Icons.tune_outlined),
        const SizedBox(height: 20),
        _labeledField(context,
          label: 'Application Name',
          value: s.appName,
          onChanged: (v) { s.appName = v; onChanged(); },
        ),
        const SizedBox(height: 14),
        _labeledField(context,
          label: 'Application Description',
          value: s.appDescription,
          onChanged: (v) { s.appDescription = v; onChanged(); },
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, c) {
          final row = c.maxWidth >= 500;
          final lang = _labeledDropdown<String>(context,
            label: 'Language',
            value: s.language,
            items: _languages,
            onChanged: (v) { if (v != null) { s.language = v; onChanged(); } },
          );
          final fmt = _labeledDropdown<String>(context,
            label: 'Date Format',
            value: s.dateFormat,
            items: _dateFormats,
            onChanged: (v) { if (v != null) { s.dateFormat = v; onChanged(); } },
          );
          if (row) {
            return Row(children: [
              Expanded(child: lang),
              const SizedBox(width: 14),
              Expanded(child: fmt),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lang, const SizedBox(height: 14), fmt,
          ]);
        }),
        const SizedBox(height: 14),
        _labeledDropdown<String>(context,
          label: 'Time Zone',
          value: s.timeZone,
          items: _timeZones,
          onChanged: (v) { if (v != null) { s.timeZone = v; onChanged(); } },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 2 — Appearance
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  final _SettingsState s;
  final VoidCallback onChanged;
  const _AppearanceSection({required this.s, required this.onChanged});

  static const List<String> _themes    = ['Light', 'Dark', 'System'];
  static const List<String> _sidebars  = ['Always visible', 'Auto-hide', 'Collapsed'];
  static const List<String> _densities = ['Comfortable', 'Compact', 'Spacious'];

  void _applyThemeNow(BuildContext context, String themeLabel) {
    final notifier = ThemeNotifier.of(context);
    switch (themeLabel) {
      case 'Dark':   notifier.setMode(ThemeMode.dark);
      case 'System': notifier.setMode(ThemeMode.system);
      default:       notifier.setMode(ThemeMode.light);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final divColor   = AppTheme.divider(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);

    final notifierMode = ThemeNotifier.of(context).mode;
    final syncedTheme = notifierMode == ThemeMode.dark
        ? 'Dark'
        : notifierMode == ThemeMode.system ? 'System' : 'Light';

    return _SettingsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading(context, 'Appearance', Icons.palette_outlined),
        const SizedBox(height: 20),
        Text('Theme',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: textPrimary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _themes.map((t) {
            final active = syncedTheme == t;
            final icon = t == 'Light'
                ? Icons.light_mode_outlined
                : t == 'Dark' ? Icons.dark_mode_outlined
                    : Icons.brightness_auto_outlined;
            return _ThemeOption(
              label: t, icon: icon, isActive: active,
              onTap: () {
                s.theme = t;
                onChanged();
                _applyThemeNow(context, t);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: divColor),
        const SizedBox(height: 4),
        _switchRow(context,
          label: 'Compact Mode',
          description: 'Reduce spacing for denser information display.',
          value: s.compactMode,
          onChanged: (v) { s.compactMode = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, c) {
          final row = c.maxWidth >= 500;
          final sidebar = _labeledDropdown<String>(context,
            label: 'Sidebar Behavior',
            value: s.sidebarBehavior,
            items: _sidebars,
            onChanged: (v) { if (v != null) { s.sidebarBehavior = v; onChanged(); } },
          );
          final density = _labeledDropdown<String>(context,
            label: 'Interface Density',
            value: s.density,
            items: _densities,
            onChanged: (v) { if (v != null) { s.density = v; onChanged(); } },
          );
          if (row) {
            return Row(children: [
              Expanded(child: sidebar),
              const SizedBox(width: 14),
              Expanded(child: density),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            sidebar, const SizedBox(height: 14), density,
          ]);
        }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryLighter(brightness),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Theme changes apply immediately. MarketFlow\'s purple identity is preserved in all modes.',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ThemeOption extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ThemeOption({
    required this.label, required this.icon,
    required this.isActive, required this.onTap,
  });
  @override State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final activeBg    = AppTheme.primaryLighter(brightness);
    final hoverBg     = AppTheme.primaryLighter(brightness);
    final borderColor = AppTheme.border(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.isActive ? activeBg
                : _hovered ? hoverBg : surfColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: widget.isActive ? AppColors.primary : borderColor,
              width: widget.isActive ? 2 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon,
                size: 22,
                color: widget.isActive ? AppColors.primary : textSec),
            const SizedBox(height: 6),
            Text(widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive ? AppColors.primary : textPrimary,
                )),
            if (widget.isActive) ...[
              const SizedBox(height: 4),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 3 — Notifications
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsSection extends StatelessWidget {
  final _SettingsState s;
  final VoidCallback onChanged;
  const _NotificationsSection({required this.s, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final divColor   = AppTheme.divider(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return _SettingsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading(context, 'Notifications', Icons.notifications_outlined),
        const SizedBox(height: 8),
        _switchRow(context,
          label: 'Enable Notifications',
          description: 'Receive in-app alerts for activity across MarketFlow.',
          value: s.enableNotifications,
          onChanged: (v) { s.enableNotifications = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Email Notifications',
          description: 'Send notification summaries to your registered email.',
          value: s.emailNotifications,
          onChanged: (v) { s.emailNotifications = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text('Notification Types',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: textSec)),
        ),
        _switchRow(context,
          label: 'Campaign Notifications',
          description: 'Alerts for campaign completions, pauses, and milestones.',
          value: s.campaignNotifications,
          onChanged: (v) { s.campaignNotifications = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Lead Notifications',
          description: 'Notify when leads are assigned or change status.',
          value: s.leadNotifications,
          onChanged: (v) { s.leadNotifications = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Customer Notifications',
          description: 'Alerts when new customers are added or updated.',
          value: s.customerNotifications,
          onChanged: (v) { s.customerNotifications = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Budget Alerts',
          description: 'Warn when budget thresholds are approaching or exceeded.',
          value: s.budgetAlerts,
          onChanged: (v) { s.budgetAlerts = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Automation Alerts',
          description: 'Notify on automation failures or completed workflows.',
          value: s.automationAlerts,
          onChanged: (v) { s.automationAlerts = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Report Notifications',
          description: 'Alert when scheduled reports are generated and ready.',
          value: s.reportNotifications,
          onChanged: (v) { s.reportNotifications = v; onChanged(); },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 4 — Security
// ─────────────────────────────────────────────────────────────────────────────

class _SecuritySection extends StatelessWidget {
  final _SettingsState s;
  final VoidCallback onChanged;
  final VoidCallback onChangePassword;
  const _SecuritySection({
    required this.s,
    required this.onChanged,
    required this.onChangePassword,
  });

  static const List<Map<String, String>> _sessions = [
    {'device': 'Chrome on Windows', 'location': 'Addis Ababa, ET', 'time': 'Active now'},
    {'device': 'Safari on iPhone',  'location': 'Addis Ababa, ET', 'time': '2 hours ago'},
    {'device': 'Firefox on MacOS',  'location': 'Nairobi, KE',     'time': '3 days ago'},
  ];

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final surfVar     = AppTheme.surfaceVariant(brightness);
    final borderColor = AppTheme.border(brightness);
    final divColor    = AppTheme.divider(brightness);
    final successBg   = AppTheme.successBg(brightness);

    return _SettingsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading(context, 'Security', Icons.lock_outline),
        const SizedBox(height: 20),

        // Password row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfVar,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: const Icon(Icons.key_outlined, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Password',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: textPrimary)),
                Text('Last changed: ${s.lastPasswordChange}',
                    style: TextStyle(fontSize: 12, color: textSec)),
              ],
            )),
            OutlinedButton(
              onPressed: onChangePassword,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Change', style: TextStyle(fontSize: 13)),
            ),
          ]),
        ),

        const SizedBox(height: 16),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Two-Factor Authentication',
          description: 'Add an extra layer of security with 2FA on sign-in.',
          value: s.twoFactor,
          onChanged: (v) { s.twoFactor = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Login Alerts',
          description: 'Email me when a new device signs into my account.',
          value: s.loginAlerts,
          onChanged: (v) { s.loginAlerts = v; onChanged(); },
        ),

        const SizedBox(height: 16),
        Divider(height: 1, color: divColor),
        const SizedBox(height: 16),

        Row(children: [
          Icon(Icons.devices_outlined, size: 16, color: textSec),
          const SizedBox(width: 6),
          Text('Active Sessions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: textPrimary)),
        ]),
        const SizedBox(height: 12),
        ..._sessions.map((session) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfVar,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: borderColor),
            ),
            child: Row(children: [
              Icon(
                session['device']!.contains('iPhone')
                    ? Icons.smartphone_outlined
                    : Icons.computer_outlined,
                size: 18, color: textSec,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session['device']!,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: textPrimary)),
                  Text('${session['location']} · ${session['time']}',
                      style: TextStyle(fontSize: 11, color: textSec)),
                ],
              )),
              if (session['time'] == 'Active now')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: successBg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                  child: const Text('Current',
                      style: TextStyle(fontSize: 11, color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                )
              else
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Text('Revoke',
                      style: TextStyle(fontSize: 12, color: AppColors.danger)),
                ),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 5 — Privacy
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacySection extends StatelessWidget {
  final _SettingsState s;
  final VoidCallback onChanged;
  const _PrivacySection({required this.s, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final divColor   = AppTheme.divider(brightness);

    return _SettingsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading(context, 'Privacy', Icons.privacy_tip_outlined),
        const SizedBox(height: 8),
        _switchRow(context,
          label: 'Profile Visibility',
          description: 'Allow other team members to see your profile information.',
          value: s.profileVisibility,
          onChanged: (v) { s.profileVisibility = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Activity Visibility',
          description: 'Show your recent activity and actions to other users.',
          value: s.activityVisibility,
          onChanged: (v) { s.activityVisibility = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Data Preferences',
          description: 'Allow MarketFlow to personalise features based on your usage.',
          value: s.dataPreferences,
          onChanged: (v) { s.dataPreferences = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Analytics Preferences',
          description: 'Share anonymised usage data to help improve the product.',
          value: s.analyticsPreferences,
          onChanged: (v) { s.analyticsPreferences = v; onChanged(); },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 6 — Application Preferences
// ─────────────────────────────────────────────────────────────────────────────

class _AppPreferencesSection extends StatelessWidget {
  final _SettingsState s;
  final VoidCallback onChanged;
  const _AppPreferencesSection({required this.s, required this.onChanged});

  static const List<String> _landingPages = [
    'Dashboard', 'Campaigns', 'Leads', 'Customers', 'Reports',
  ];
  static const List<String> _languages   = ['English', 'Amharic'];
  static const List<String> _dateFormats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];
  static const List<String> _timeFormats = ['24-hour', '12-hour (AM/PM)'];
  static const List<int>    _rowCounts   = [5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final divColor   = AppTheme.divider(brightness);
    final infoBg     = AppTheme.infoBg(brightness);

    return _SettingsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading(context, 'Application Preferences', Icons.apps_outlined),
        const SizedBox(height: 20),
        _labeledDropdown<String>(context,
          label: 'Default Landing Page',
          value: s.defaultLandingPage,
          items: _landingPages,
          onChanged: (v) { if (v != null) { s.defaultLandingPage = v; onChanged(); } },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, c) {
          final row = c.maxWidth >= 500;
          final lang = _labeledDropdown<String>(context,
            label: 'Language',
            value: s.language,
            items: _languages,
            onChanged: (v) { if (v != null) { s.language = v; onChanged(); } },
          );
          final dateFmt = _labeledDropdown<String>(context,
            label: 'Date Format',
            value: s.dateFormat,
            items: _dateFormats,
            onChanged: (v) { if (v != null) { s.dateFormat = v; onChanged(); } },
          );
          if (row) {
            return Row(children: [
              Expanded(child: lang),
              const SizedBox(width: 14),
              Expanded(child: dateFmt),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lang, const SizedBox(height: 14), dateFmt,
          ]);
        }),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (_, c) {
          final row = c.maxWidth >= 500;
          final timeFmt = _labeledDropdown<String>(context,
            label: 'Time Format',
            value: s.timeFormat,
            items: _timeFormats,
            onChanged: (v) { if (v != null) { s.timeFormat = v; onChanged(); } },
          );
          final rowCount = _labeledDropdown<int>(context,
            label: 'Default Table Rows',
            value: s.defaultTableRows,
            items: _rowCounts,
            display: (i) => '$i rows',
            onChanged: (v) { if (v != null) { s.defaultTableRows = v; onChanged(); } },
          );
          if (row) {
            return Row(children: [
              Expanded(child: timeFmt),
              const SizedBox(width: 14),
              Expanded(child: rowCount),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            timeFmt, const SizedBox(height: 14), rowCount,
          ]);
        }),
        const SizedBox(height: 16),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Compact Mode',
          description: 'Synced with Appearance — reduces layout spacing globally.',
          value: s.compactMode,
          onChanged: (v) { s.compactMode = v; onChanged(); },
        ),
        Divider(height: 1, color: divColor),
        _switchRow(context,
          label: 'Auto-Refresh',
          description: 'Automatically refresh data every 5 minutes.',
          value: s.autoRefresh,
          onChanged: (v) { s.autoRefresh = v; onChanged(); },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: infoBg,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Language and Date Format here share state with the General section.',
                style: TextStyle(fontSize: 12, color: AppColors.info),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ResetConfirmDialog — theme-aware
// ─────────────────────────────────────────────────────────────────────────────

class _ResetConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ResetConfirmDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final divColor    = AppTheme.divider(brightness);
    final dangerBg    = AppTheme.dangerBg(brightness);
    final surfColor   = AppTheme.surfaceColor(brightness);

    return Dialog(
      backgroundColor: surfColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dangerBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: const Icon(Icons.restart_alt_outlined,
                    color: AppColors.danger, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Reset to Default',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: textPrimary)),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: textSec),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            Divider(height: 28, color: divColor),
            Text(
              'This will reset all settings to their factory defaults. '
              'Any customisations you have made will be lost.',
              style: TextStyle(fontSize: 13, color: textSec, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: textSec)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChangePasswordDialog — theme-aware
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const _ChangePasswordDialog({required this.onSaved});
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _showCurrent   = false;
  bool _showNew       = false;
  bool _showConfirm   = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final divColor    = AppTheme.divider(brightness);
    final surfColor   = AppTheme.surfaceColor(brightness);

    return Dialog(
      backgroundColor: surfColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLighter(brightness),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Change Password',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                          color: textPrimary)),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSec),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              Divider(height: 28, color: divColor),
              _PasswordField(
                controller: _currentCtrl,
                label: 'Current Password',
                obscure: !_showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _newCtrl,
                label: 'New Password',
                obscure: !_showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 8) return 'Must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirmCtrl,
                label: 'Confirm New Password',
                obscure: !_showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: textSec)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(context).pop();
                      widget.onSaved();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update Password'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PasswordField — theme-aware
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String>? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final inputFill   = AppTheme.inputFill(brightness);
    final borderColor = AppTheme.border(brightness);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: textPrimary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        style: TextStyle(fontSize: 13, color: textPrimary),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18, color: textSec,
            ),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: inputFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}
