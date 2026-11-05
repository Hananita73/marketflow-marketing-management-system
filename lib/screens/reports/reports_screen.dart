import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import 'package:flutter/services.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/report.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportsScreen — entry point
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  late List<ReportRecord> _records;
  String _searchQuery = '';
  ReportType? _typeFilter;
  ReportStatus? _statusFilter;
  String _sortBy = 'name'; // 'name' | 'date' | 'type'
  bool _sortAsc = true;

  // timers for simulated generate
  final Map<String, Timer> _generateTimers = {};

  @override
  void initState() {
    super.initState();
    _records = List.from(ReportRepository.getAll());
  }

  @override
  void dispose() {
    for (final t in _generateTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  // ── Derived data ─────────────────────────────────────────────────────────
  List<ReportRecord> get _filtered {
    var list = _records.where((r) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.type.label.toLowerCase().contains(q);
      final matchType = _typeFilter == null || r.type == _typeFilter;
      final matchStatus = _statusFilter == null || r.status == _statusFilter;
      return matchSearch && matchType && matchStatus;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'date':
          final ad = a.lastGenerated ?? DateTime(2000);
          final bd = b.lastGenerated ?? DateTime(2000);
          cmp = bd.compareTo(ad); // newest first by default
          break;
        case 'type':
          cmp = a.type.label.compareTo(b.type.label);
          break;
        default:
          cmp = a.name.compareTo(b.name);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  int get _totalReports => _records.length;
  int get _generatedThisMonth => _records
      .where((r) =>
          r.lastGenerated != null &&
          r.lastGenerated!.year == 2026 &&
          r.lastGenerated!.month == 8)
      .length;
  int get _scheduled =>
      _records.where((r) => r.schedule != ReportSchedule.none).length;
  int get _shared =>
      _records.where((r) => r.recipients.isNotEmpty).length;


  // ── Actions ──────────────────────────────────────────────────────────────
  void _showSnackbar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AppColors.success,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
      ),
    );
  }

  void _generateReport(ReportRecord r) {
    setState(() {
      final idx = _records.indexWhere((x) => x.id == r.id);
      if (idx == -1) return;
      _records[idx] = _records[idx].copyWith(status: ReportStatus.generating);
      ReportRepository.update(_records[idx]);
    });
    _generateTimers[r.id]?.cancel();
    _generateTimers[r.id] = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        final idx = _records.indexWhere((x) => x.id == r.id);
        if (idx == -1) return;
        _records[idx] = _records[idx].copyWith(
          status: ReportStatus.ready,
          lastGenerated: DateTime.now(),
        );
        ReportRepository.update(_records[idx]);
      });
      _showSnackbar('"${r.name}" generated successfully.');
    });
  }

  void _downloadReport(ReportRecord r) {
    _showSnackbar('"${r.name}" download started — PDF will be ready shortly.');
  }

  void _exportReport(ReportRecord r) {
    showDialog(
      context: context,
      builder: (_) => _ExportDialog(reportName: r.name, onExport: (fmt) {
        Navigator.of(context).pop();
        _showSnackbar('"${r.name}" exported as $fmt successfully.');
      }),
    );
  }

  void _deleteReport(ReportRecord r) {
    if (!AccessService.requireDelete(context, 'Reports')) return;
    showDialog(
      context: context,
      builder: (_) => _DeleteConfirmDialog(
        reportName: r.name,
        onConfirm: () {
          Navigator.of(context).pop();
          setState(() {
            _records.removeWhere((x) => x.id == r.id);
            ReportRepository.delete(r.id);
          });
          _showSnackbar('"${r.name}" deleted.', color: AppColors.danger);
        },
      ),
    );
  }

  void _viewReport(ReportRecord r) {
    showDialog(
      context: context,
      builder: (_) => _ReportPreviewDialog(record: r),
    );
  }

  void _editReport(ReportRecord r) {
    if (!AccessService.requireEdit(context, 'Reports')) return;
    showDialog(
      context: context,
      builder: (_) => _CreateEditReportDialog(
        existing: r,
        onSave: (updated) {
          Navigator.of(context).pop();
          setState(() {
            final idx = _records.indexWhere((x) => x.id == updated.id);
            if (idx != -1) {
              _records[idx] = updated;
              ReportRepository.update(updated);
            }
          });
          _showSnackbar('"${updated.name}" updated.');
        },
      ),
    );
  }

  void _createReport() {
    if (!AccessService.requireCreate(context, 'Reports')) return;
    showDialog(
      context: context,
      builder: (_) => _CreateEditReportDialog(
        onSave: (newRec) {
          Navigator.of(context).pop();
          setState(() {
            _records.add(newRec);
            ReportRepository.add(newRec);
          });
          _showSnackbar('"${newRec.name}" created — generating now…');
          _generateReport(newRec);
        },
      ),
    );
  }


  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered = _filtered;
    return CustomScrollView(
      slivers: [
        // ── Sticky header ─────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _ReportsHeaderDelegate(
            onCreatePressed: _createReport,
            brightness: brightness,
          ),
        ),

        // ── Scrollable content ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.sectionSpacing,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KpiRow(
                  total: _totalReports,
                  thisMonth: _generatedThisMonth,
                  scheduled: _scheduled,
                  shared: _shared,
                ),
                const SizedBox(height: AppConstants.sectionSpacing),
                _Toolbar(
                  searchQuery: _searchQuery,
                  typeFilter: _typeFilter,
                  statusFilter: _statusFilter,
                  sortBy: _sortBy,
                  sortAsc: _sortAsc,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onTypeChanged: (v) => setState(() => _typeFilter = v),
                  onStatusChanged: (v) => setState(() => _statusFilter = v),
                  onSortChanged: (by, asc) =>
                      setState(() { _sortBy = by; _sortAsc = asc; }),
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                _ReportLibrary(
                  records: filtered,
                  onView: _viewReport,
                  onEdit: _editReport,
                  onGenerate: _generateReport,
                  onDownload: _downloadReport,
                  onExport: _exportReport,
                  onDelete: _deleteReport,
                  onCreate: _createReport,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Sticky header delegate
// ─────────────────────────────────────────────────────────────────────────────

class _ReportsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onCreatePressed;
  final Brightness brightness;

  const _ReportsHeaderDelegate({
    required this.onCreatePressed,
    required this.brightness,
  });

  static const double _height = 72.0;

  @override double get minExtent => _height;
  @override double get maxExtent => _height;

  @override
  bool shouldRebuild(_ReportsHeaderDelegate old) =>
      old.brightness != brightness || old.onCreatePressed != onCreatePressed;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: AppTheme.surfaceColor(brightness),
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 12,
        ),
        child: _ReportPageHeader(onCreatePressed: onCreatePressed),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Header
// ─────────────────────────────────────────────────────────────────────────────

class _ReportPageHeader extends StatelessWidget {
  final VoidCallback onCreatePressed;
  const _ReportPageHeader({required this.onCreatePressed});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: const Icon(Icons.bar_chart_outlined, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Reports',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                'Analyze marketing performance and generate actionable insights.',
                style: TextStyle(color: textSec, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _CreateReportButton(onPressed: onCreatePressed),
      ],
    );
  }
}

class _CreateReportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CreateReportButton({required this.onPressed});

  @override
  State<_CreateReportButton> createState() => _CreateReportButtonState();
}

class _CreateReportButtonState extends State<_CreateReportButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMedium),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Create Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// KPI Row
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final int total;
  final int thisMonth;
  final int scheduled;
  final int shared;

  const _KpiRow({
    required this.total,
    required this.thisMonth,
    required this.scheduled,
    required this.shared,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData(
        label: 'Total Reports',
        value: '$total',
        change: '+2',
        isPositive: true,
        subtitle: 'vs last month',
        icon: Icons.bar_chart_outlined,
        iconColor: AppColors.primary,
      ),
      _KpiData(
        label: 'Generated This Month',
        value: '$thisMonth',
        change: '+3',
        isPositive: true,
        subtitle: 'vs last month',
        icon: Icons.receipt_long_outlined,
        iconColor: AppColors.success,
      ),
      _KpiData(
        label: 'Scheduled',
        value: '$scheduled',
        change: '0',
        isPositive: true,
        subtitle: 'auto-run reports',
        icon: Icons.schedule_outlined,
        iconColor: AppColors.warning,
      ),
      _KpiData(
        label: 'Shared',
        value: '$shared',
        change: '+1',
        isPositive: true,
        subtitle: 'with recipients',
        icon: Icons.share_outlined,
        iconColor: AppColors.info,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // desktop: 4 columns / tablet: 2×2 / mobile: 1 column
      final cols = w >= 900 ? 4 : (w >= 500 ? 2 : 1);
      final gap = AppConstants.itemSpacing;
      final cardW = (w - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards
            .map((d) => SizedBox(width: cardW, child: _KpiCard(data: d)))
            .toList(),
      );
    });
  }
}

class _KpiData {
  final String label;
  final String value;
  final String change;
  final bool isPositive;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _KpiData({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final badgeColor = data.isPositive ? AppColors.success : AppColors.danger;
    final badgeBg    = data.isPositive
        ? AppTheme.successBg(brightness)
        : AppTheme.dangerBg(brightness);
    final badgeIcon  = data.isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(data.label,
                    style: TextStyle(
                        color: AppTheme.textSecondary(brightness),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: data.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Icon(data.icon, size: 18, color: data.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(data.value,
              style: TextStyle(
                  color: AppTheme.textPrimary(brightness),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 10, color: badgeColor),
                    const SizedBox(width: 2),
                    Text(data.change,
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.subtitle,
                    style: TextStyle(
                        color: AppTheme.textSecondary(brightness), fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final String searchQuery;
  final ReportType? typeFilter;
  final ReportStatus? statusFilter;
  final String sortBy;
  final bool sortAsc;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ReportType?> onTypeChanged;
  final ValueChanged<ReportStatus?> onStatusChanged;
  final void Function(String by, bool asc) onSortChanged;

  const _Toolbar({
    required this.searchQuery,
    required this.typeFilter,
    required this.statusFilter,
    required this.sortBy,
    required this.sortAsc,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final inputFill  = AppTheme.inputFill(brightness);
    final borderCol  = AppTheme.border(brightness);

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 640;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Search
          SizedBox(
            width: narrow ? constraints.maxWidth : 220,
            height: 40,
            child: TextField(
              controller:
                  TextEditingController(text: searchQuery)
                    ..selection = TextSelection.collapsed(
                        offset: searchQuery.length),
              onChanged: onSearchChanged,
              style: TextStyle(fontSize: 13, color: textPri),
              decoration: InputDecoration(
                hintText: 'Search reports…',
                hintStyle: TextStyle(fontSize: 13, color: textSec),
                prefixIcon: Icon(Icons.search_outlined, size: 18, color: textSec),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          // Type filter
          _DropdownFilter<ReportType?>(
            hint: 'Report Type',
            value: typeFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Types')),
              ...ReportType.values.map((t) => DropdownMenuItem(
                  value: t, child: Text(t.label))),
            ],
            onChanged: onTypeChanged,
          ),
          // Status filter
          _DropdownFilter<ReportStatus?>(
            hint: 'Status',
            value: statusFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...ReportStatus.values.map((s) => DropdownMenuItem(
                  value: s, child: Text(s.label))),
            ],
            onChanged: onStatusChanged,
          ),
          // Sort
          _SortControl(sortBy: sortBy, sortAsc: sortAsc, onChanged: onSortChanged),
        ],
      );
    });
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.inputFill(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness))),
          items: items,
          onChanged: (v) => onChanged(v as T),
          dropdownColor: AppTheme.surfaceColor(brightness),
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
          icon: Icon(Icons.keyboard_arrow_down_outlined,
              size: 18, color: AppTheme.iconColor(brightness)),
          isDense: true,
        ),
      ),
    );
  }
}

class _SortControl extends StatelessWidget {
  final String sortBy;
  final bool sortAsc;
  final void Function(String, bool) onChanged;

  const _SortControl({required this.sortBy, required this.sortAsc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final options = {'name': 'Name', 'date': 'Last Generated', 'type': 'Type'};
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.inputFill(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort_outlined, size: 16, color: AppTheme.iconColor(brightness)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortBy,
              dropdownColor: AppTheme.surfaceColor(brightness),
              items: options.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => onChanged(v ?? 'name', sortAsc),
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
              icon: const SizedBox.shrink(),
              isDense: true,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => onChanged(sortBy, !sortAsc),
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                sortAsc ? Icons.arrow_upward_outlined : Icons.arrow_downward_outlined,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Report Library (card grid + empty state)
// ─────────────────────────────────────────────────────────────────────────────

class _ReportLibrary extends StatelessWidget {
  final List<ReportRecord> records;
  final void Function(ReportRecord) onView;
  final void Function(ReportRecord) onEdit;
  final void Function(ReportRecord) onGenerate;
  final void Function(ReportRecord) onDownload;
  final void Function(ReportRecord) onExport;
  final void Function(ReportRecord) onDelete;
  final VoidCallback onCreate;

  const _ReportLibrary({
    required this.records,
    required this.onView,
    required this.onEdit,
    required this.onGenerate,
    required this.onDownload,
    required this.onExport,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _EmptyState(onCreate: onCreate);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 1000 ? 3 : (w >= 620 ? 2 : 1);
      final gap = AppConstants.itemSpacing;
      final cardW = (w - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: records
            .map((r) => SizedBox(
                  width: cardW,
                  child: _ReportCard(
                    record: r,
                    onView: () => onView(r),
                    onEdit: () => onEdit(r),
                    onGenerate: () => onGenerate(r),
                    onDownload: () => onDownload(r),
                    onExport: () => onExport(r),
                    onDelete: () => onDelete(r),
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryLighter(brightness),
                borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              ),
              child: const Icon(Icons.bar_chart_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No reports found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary(brightness),
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Text('Try adjusting your filters, or create a new report.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness))),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Report Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatefulWidget {
  final ReportRecord record;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;
  final VoidCallback onDownload;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.record,
    required this.onView,
    required this.onEdit,
    required this.onGenerate,
    required this.onDownload,
    required this.onExport,
    required this.onDelete,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _hovered = false;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness    = Theme.of(context).brightness;
    final cardBg        = AppTheme.cardColor(brightness);
    final borderCol     = AppTheme.border(brightness);
    final textPri       = AppTheme.textPrimary(brightness);
    final textSec       = AppTheme.textSecondary(brightness);
    final priLighter    = AppTheme.primaryLighter(brightness);
    final r             = widget.record;
    final isGenerating  = r.status == ReportStatus.generating;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: _hovered ? AppColors.primary.withValues(alpha: 0.4) : borderCol,
          ),
          boxShadow: _hovered
              ? [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: priLighter,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Icon(r.type.icon, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(r.type.label,
                            style: TextStyle(fontSize: 12, color: textSec)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: r.status),
                ],
              ),
            ),

            // ── Description ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
              child: Text(
                r.description,
                style: TextStyle(fontSize: 12, color: textSec, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),

            // ── Generating skeleton ──────────────────────────────────
            if (isGenerating)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.autorenew_outlined, size: 12, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text('Generating report…',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      child: LinearProgressIndicator(
                        backgroundColor: AppTheme.warningBg(brightness),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // ── Divider ──────────────────────────────────────────────
            Divider(height: 1, color: AppTheme.divider(brightness)),

            // ── Footer ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.cardPadding, vertical: 10),
              child: Row(children: [
                Icon(Icons.person_outline, size: 12, color: textSec),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(r.createdBy,
                      style: TextStyle(fontSize: 11, color: textSec),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.access_time_outlined, size: 12, color: textSec),
                const SizedBox(width: 4),
                Text(_formatDate(r.lastGenerated),
                    style: TextStyle(fontSize: 11, color: textSec)),
              ]),
            ),

            // ── Actions ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppConstants.cardPadding, 0,
                  AppConstants.cardPadding, AppConstants.cardPadding),
              child: _CardActions(
                record: r,
                onView: widget.onView,
                onEdit: widget.onEdit,
                onGenerate: widget.onGenerate,
                onDownload: widget.onDownload,
                onExport: widget.onExport,
                onDelete: widget.onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ReportStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Actions
// ─────────────────────────────────────────────────────────────────────────────

class _CardActions extends StatelessWidget {
  final ReportRecord record;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;
  final VoidCallback onDownload;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _CardActions({
    required this.record,
    required this.onView,
    required this.onEdit,
    required this.onGenerate,
    required this.onDownload,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness   = Theme.of(context).brightness;
    final textSec      = AppTheme.textSecondary(brightness);
    final menuBg       = AppTheme.surfaceColor(brightness);
    final borderCol    = AppTheme.border(brightness);
    final isGenerating = record.status == ReportStatus.generating;

    return Row(
      children: [
        _ActionButton(
          icon: Icons.visibility_outlined,
          label: 'View',
          color: AppColors.primary,
          onPressed: isGenerating ? null : onView,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.download_outlined,
          label: 'Download',
          color: AppColors.info,
          onPressed: record.status == ReportStatus.ready ? onDownload : null,
        ),
        const Spacer(),
        SizedBox(
          width: 32, height: 32,
          child: PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_outlined, size: 18, color: textSec),
            tooltip: 'More actions',
            color: menuBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                side: BorderSide(color: borderCol)),
            onSelected: (v) {
              switch (v) {
                case 'edit':     onEdit();     break;
                case 'generate': onGenerate(); break;
                case 'export':   onExport();   break;
                case 'delete':   onDelete();   break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 16, color: textSec),
                  const SizedBox(width: 8),
                  const Text('Edit', style: TextStyle(fontSize: 13)),
                ]),
              ),
              PopupMenuItem(
                value: 'generate',
                enabled: !isGenerating,
                child: Row(children: [
                  Icon(Icons.autorenew_outlined, size: 16,
                      color: isGenerating
                          ? textSec.withValues(alpha: 0.4)
                          : textSec),
                  const SizedBox(width: 8),
                  Text('Generate',
                      style: TextStyle(
                          fontSize: 13,
                          color: isGenerating ? textSec.withValues(alpha: 0.4) : null)),
                ]),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.upload_file_outlined, size: 16, color: textSec),
                  const SizedBox(width: 8),
                  const Text('Export', style: TextStyle(fontSize: 13)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(fontSize: 13, color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final borderCol  = AppTheme.border(brightness);
    final disabled   = widget.onPressed == null;
    final bg = _hovered && !disabled
        ? widget.color.withValues(alpha: 0.10)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          border: Border.all(
              color: disabled
                  ? borderCol
                  : _hovered
                      ? widget.color.withValues(alpha: 0.4)
                      : borderCol),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon,
                      size: 14,
                      color: disabled
                          ? AppTheme.textSecondary(brightness).withValues(alpha: 0.4)
                          : widget.color),
                  const SizedBox(width: 4),
                  Text(widget.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: disabled
                              ? AppTheme.textSecondary(brightness).withValues(alpha: 0.4)
                              : widget.color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Create / Edit Report Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CreateEditReportDialog extends StatefulWidget {
  final ReportRecord? existing;
  final void Function(ReportRecord) onSave;

  const _CreateEditReportDialog({this.existing, required this.onSave});

  @override
  State<_CreateEditReportDialog> createState() =>
      _CreateEditReportDialogState();
}

class _CreateEditReportDialogState
    extends State<_CreateEditReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _rangeCtrl;
  late final TextEditingController _recipientsCtrl;
  late ReportType _type;
  late ReportSchedule _schedule;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _rangeCtrl = TextEditingController(
        text: e?.dateRange ?? 'Aug 1 – Aug 31, 2026');
    _recipientsCtrl = TextEditingController(
        text: e?.recipients.join(', ') ?? '');
    _type = e?.type ?? ReportType.campaignPerformance;
    _schedule = e?.schedule ?? ReportSchedule.none;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _rangeCtrl.dispose();
    _recipientsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final recipients = _recipientsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final record = ReportRecord(
      id: widget.existing?.id ?? ReportRepository.nextId(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      type: _type,
      status: widget.existing?.status ?? ReportStatus.generating,
      lastGenerated: widget.existing?.lastGenerated,
      createdBy: 'Hana Tsegaye',
      dateRange: _rangeCtrl.text.trim(),
      schedule: _schedule,
      recipients: recipients,
    );
    widget.onSave(record);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit     = widget.existing != null;
    final title      = isEdit ? 'Edit Report' : 'Create Report';
    final w          = MediaQuery.of(context).size.width;
    final isMobile   = w < AppConstants.mobileBreakpoint;
    final brightness = Theme.of(context).brightness;
    final surfaceBg  = AppTheme.surfaceColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final priLighter = AppTheme.primaryLighter(brightness);

    final content = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Name
          _FormLabel(text: 'Report Name *', color: textPri),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDeco('e.g. Q3 Campaign Summary', brightness),
            style: TextStyle(fontSize: 14, color: textPri),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Report name is required' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Report Type
          _FormLabel(text: 'Report Type *', color: textPri),
          const SizedBox(height: 6),
          DropdownButtonFormField<ReportType>(
            initialValue: _type,
            decoration: _inputDeco('', brightness),
            dropdownColor: surfaceBg,
            style: TextStyle(fontSize: 14, color: textPri),
            items: ReportType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
            validator: (v) => v == null ? 'Please select a type' : null,
          ),
          const SizedBox(height: 16),

          // Date Range
          _FormLabel(text: 'Date Range', color: textPri),
          const SizedBox(height: 6),
          TextFormField(
            controller: _rangeCtrl,
            decoration: _inputDeco('e.g. Aug 1 – Aug 31, 2026', brightness),
            style: TextStyle(fontSize: 14, color: textPri),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Description
          _FormLabel(text: 'Description', color: textPri),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl,
            decoration: _inputDeco('Short description of this report…', brightness),
            style: TextStyle(fontSize: 14, color: textPri),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 16),

          // Schedule
          _FormLabel(text: 'Schedule', color: textPri),
          const SizedBox(height: 6),
          DropdownButtonFormField<ReportSchedule>(
            initialValue: _schedule,
            decoration: _inputDeco('', brightness),
            dropdownColor: surfaceBg,
            style: TextStyle(fontSize: 14, color: textPri),
            items: ReportSchedule.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _schedule = v ?? _schedule),
          ),
          const SizedBox(height: 16),

          // Recipients
          _FormLabel(text: 'Recipients', color: textPri),
          const SizedBox(height: 4),
          Text('Comma-separated email addresses',
              style: TextStyle(fontSize: 11, color: textSec)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _recipientsCtrl,
            decoration: _inputDeco('e.g. alice@example.com, bob@example.com', brightness),
            style: TextStyle(fontSize: 14, color: textPri),
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@.,_\-\s]'))
            ],
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSec,
                  side: BorderSide(color: borderCol),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                  elevation: 0,
                ),
                child: Text(isEdit ? 'Save Changes' : 'Create Report',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: surfaceBg,
        appBar: AppBar(
          title: Text(title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPri)),
          backgroundColor: surfaceBg,
          elevation: 0,
          iconTheme: IconThemeData(color: textSec),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: borderCol),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: content,
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
      backgroundColor: surfaceBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: priLighter,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: const Icon(Icons.bar_chart_outlined, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPri)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSec),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: borderCol),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, Brightness brightness) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppTheme.inputFill(brightness),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: AppTheme.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: AppTheme.border(brightness)),
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
      );
}

class _FormLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const _FormLabel({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color ?? AppTheme.textPrimary(brightness)));
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Delete Confirm Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final String reportName;
  final VoidCallback onConfirm;

  const _DeleteConfirmDialog(
      {required this.reportName, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surfaceBg  = AppTheme.surfaceColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
      backgroundColor: surfaceBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg(brightness),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                ),
                child: const Icon(Icons.delete_outline, size: 24, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              Text('Delete Report',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, color: textPri)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "$reportName"? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSec, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSec,
                        side: BorderSide(color: borderCol),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                        elevation: 0,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ExportDialog extends StatelessWidget {
  final String reportName;
  final void Function(String format) onExport;

  const _ExportDialog(
      {required this.reportName, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surfaceBg  = AppTheme.surfaceColor(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
      backgroundColor: surfaceBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.infoBg(brightness),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: const Icon(Icons.upload_file_outlined, size: 18, color: AppColors.info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Export Report',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: textPri)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: textSec),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Select export format for "$reportName":',
                  style: TextStyle(fontSize: 13, color: textSec)),
              const SizedBox(height: 16),
              _ExportFormatTile(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF Document',
                subtitle: 'Best for sharing and printing',
                color: AppColors.danger,
                onTap: () => onExport('PDF'),
              ),
              const SizedBox(height: 8),
              _ExportFormatTile(
                icon: Icons.table_chart_outlined,
                label: 'CSV Spreadsheet',
                subtitle: 'Best for data analysis',
                color: AppColors.success,
                onTap: () => onExport('CSV'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportFormatTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExportFormatTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ExportFormatTile> createState() => _ExportFormatTileState();
}

class _ExportFormatTileState extends State<_ExportFormatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgFill     = AppTheme.backgroundFill(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withValues(alpha: 0.06) : bgFill,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
              color: _hovered ? widget.color.withValues(alpha: 0.3) : borderCol),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                      Text(widget.subtitle,
                          style: TextStyle(fontSize: 11, color: textSec)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_outlined, size: 16, color: textSec),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Report Preview Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ReportPreviewDialog extends StatelessWidget {
  final ReportRecord record;
  const _ReportPreviewDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgFill     = AppTheme.backgroundFill(brightness);
    final surfaceBg  = AppTheme.surfaceColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final priLighter = AppTheme.primaryLighter(brightness);
    final w          = MediaQuery.of(context).size.width;
    final isMobile   = w < AppConstants.mobileBreakpoint;

    final body = _PreviewBody(record: record);

    if (isMobile) {
      return Scaffold(
        backgroundColor: bgFill,
        appBar: AppBar(
          title: Text(record.name,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPri),
              overflow: TextOverflow.ellipsis),
          backgroundColor: surfaceBg,
          elevation: 0,
          iconTheme: IconThemeData(color: textSec),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: borderCol),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: body,
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
      backgroundColor: bgFill,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: const BorderRadius.only(
                  topLeft:  Radius.circular(AppConstants.radiusXL),
                  topRight: Radius.circular(AppConstants.radiusXL),
                ),
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: priLighter,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Icon(record.type.icon, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.name,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: textPri)),
                        Text(record.dateRange,
                            style: TextStyle(fontSize: 12, color: textSec)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: record.status),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSec),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  final ReportRecord record;
  const _PreviewBody({required this.record});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewKpiRow(type: record.type),
        const SizedBox(height: 24),
        _PreviewSection(
          title: 'Summary',
          child: Text(
            _summaryText(record.type),
            style: TextStyle(fontSize: 13, color: textSec, height: 1.6),
          ),
        ),
        const SizedBox(height: 16),
        _PreviewSection(
          title: 'Key Insights',
          child: Column(
            children: _insights(record.type)
                .map((i) => _InsightRow(text: i))
                .toList(),
          ),
        ),
        if (_showViz(record.type)) ...[
          const SizedBox(height: 16),
          _PreviewSection(
            title: _vizTitle(record.type),
            child: _PreviewChart(type: record.type),
          ),
        ],
      ],
    );
  }

  bool _showViz(ReportType t) =>
      t == ReportType.campaignPerformance ||
      t == ReportType.roiAnalysis ||
      t == ReportType.customerGrowth ||
      t == ReportType.budgetReport;

  String _vizTitle(ReportType t) {
    switch (t) {
      case ReportType.campaignPerformance:
        return 'Performance by Channel';
      case ReportType.roiAnalysis:
        return 'ROI by Campaign Type';
      case ReportType.customerGrowth:
        return 'Monthly New Customers';
      case ReportType.budgetReport:
        return 'Budget Utilization by Channel';
      default:
        return 'Overview';
    }
  }

  String _summaryText(ReportType t) {
    switch (t) {
      case ReportType.campaignPerformance:
        return 'During the reporting period, 8 campaigns were active across 4 channels. '
            'Social Media and Email drove the highest conversion rates at 12.4% and 9.8% respectively. '
            'Total spend reached ETB 142,000 against a target of ETB 180,000, delivering '
            '2.6× average ROI. Three campaigns exceeded their click-through targets by more than 15%.';
      case ReportType.leadAnalytics:
        return 'A total of 3,248 leads were captured this period, a 14% increase year-over-year. '
            'Website organic and paid social contributed 52% of inbound volume. '
            'Average time-to-qualification dropped from 4.2 days to 3.1 days, and '
            'the lead-to-opportunity conversion rate improved from 22% to 27%.';
      case ReportType.budgetReport:
        return 'Year-to-date marketing spend stands at ETB 750,000 against a total budget of '
            'ETB 1,200,000 (62.5% utilization). Social Media and Content are on track; '
            'Paid Ads is 18% over budget while Influencer Marketing is 24% under-utilized. '
            'No corrective reallocation is currently needed.';
      case ReportType.customerGrowth:
        return '1,250 net new customers were acquired this quarter — a 25% improvement versus Q1. '
            'Churn rate held at 3.2%, down from 4.1% last quarter. '
            'Average customer lifetime value grew to ETB 8,400. '
            'Retention programs contributed to a 78% 90-day retention rate.';
      case ReportType.roiAnalysis:
        return 'Overall marketing ROI for the period is 4.35×, exceeding the 3.5× target. '
            'Brand Awareness campaigns delivered the highest absolute revenue contribution '
            'at ETB 245,000, while Retargeting achieved the best efficiency at 6.1× ROI. '
            'Email campaigns remain the most cost-effective channel at ETB 12 cost-per-acquisition.';
      case ReportType.communicationPerformance:
        return '42 email campaigns and 18 SMS broadcasts were sent this period. '
            'Average email open rate reached 34.2% (industry benchmark: 21%). '
            'Click-through rate averaged 5.8%. Unsubscribe rate remained low at 0.4%. '
            'Automated drip sequences outperformed manual sends by 2.1× on conversion.';
    }
  }

  List<String> _insights(ReportType t) {
    switch (t) {
      case ReportType.campaignPerformance:
        return [
          'Social Media campaigns exceeded click targets by 22% — consider increasing budget allocation.',
          'The "Product Launch" campaign had the highest ROI at 5.2×.',
          'Email open rates declined 8% — A/B test subject lines to recover engagement.',
          'Mobile traffic accounted for 64% of all campaign clicks.',
        ];
      case ReportType.leadAnalytics:
        return [
          'Website organic search is the #1 lead source at 28% — SEO investment is paying off.',
          'Referral leads have a 3× higher close rate than paid ads leads.',
          'Lead volume drops 40% on weekends — adjust paid ad scheduling accordingly.',
          '18% of leads go cold after 7 days without follow-up; automate day-5 re-engagement.',
        ];
      case ReportType.budgetReport:
        return [
          'Paid Ads over-spend of ETB 18,000 should be offset by reducing Influencer allocation.',
          'Content Marketing is delivering leads at 30% lower cost than last quarter.',
          'Q4 budget planning should account for a 12% projected CPL increase in paid social.',
          'ETB 450,000 remains unspent — ideal for opportunistic campaign launches.',
        ];
      case ReportType.customerGrowth:
        return [
          'Customers acquired via referral have 2.4× higher lifetime value than paid channels.',
          'Churn risk is highest in months 2–3 post-acquisition; onboarding improvement recommended.',
          'The 18–34 age segment grew 38% this quarter — tailor messaging to this cohort.',
          'Loyalty program members churn at half the rate of non-members.',
        ];
      case ReportType.roiAnalysis:
        return [
          'Retargeting delivers the best ROI at 6.1× — increase frequency cap to 5 exposures.',
          'The bottom 20% of campaigns by spend produce only 3% of revenue — review or cut.',
          'ETB 1 spent on Email generates ETB 5.80 in revenue — highest efficiency channel.',
          'Influencer campaign ROI of 1.8× is below target; renegotiate fee structures.',
        ];
      case ReportType.communicationPerformance:
        return [
          'Personalized subject lines improve open rates by 26% versus generic subject lines.',
          'SMS campaigns achieve 6× higher read rates than email for time-sensitive offers.',
          'Automated sequences have a 2.1× conversion advantage over one-time manual sends.',
          'Unsubscribe rate of 0.4% is well within the 0.5% healthy threshold.',
        ];
    }
  }
}


// Preview KPI tiles
class _PreviewKpiRow extends StatelessWidget {
  final ReportType type;
  const _PreviewKpiRow({required this.type});

  List<_PreviewKpi> _kpis(ReportType t) {
    switch (t) {
      case ReportType.campaignPerformance:
        return [
          const _PreviewKpi('Total Campaigns', '8', Icons.campaign_outlined, AppColors.primary),
          const _PreviewKpi('Total Clicks', '12,400', Icons.ads_click_outlined, AppColors.info),
          const _PreviewKpi('Conversions', '960', Icons.check_circle_outline, AppColors.success),
          const _PreviewKpi('Avg ROI', '2.6×', Icons.trending_up_outlined, AppColors.warning),
        ];
      case ReportType.leadAnalytics:
        return [
          const _PreviewKpi('Total Leads', '3,248', Icons.person_search_outlined, AppColors.primary),
          const _PreviewKpi('Conversion Rate', '27%', Icons.swap_horiz_outlined, AppColors.success),
          const _PreviewKpi('Avg Time-to-Close', '3.1 days', Icons.timer_outlined, AppColors.warning),
          const _PreviewKpi('Qualified Leads', '878', Icons.verified_outlined, AppColors.info),
        ];
      case ReportType.budgetReport:
        return [
          const _PreviewKpi('Total Budget', 'ETB 1,200,000', Icons.account_balance_wallet_outlined, AppColors.primary),
          const _PreviewKpi('Spent', 'ETB 750,000', Icons.payments_outlined, AppColors.danger),
          const _PreviewKpi('Remaining', 'ETB 450,000', Icons.savings_outlined, AppColors.success),
          const _PreviewKpi('Utilization', '62.5%', Icons.pie_chart_outline, AppColors.warning),
        ];
      case ReportType.customerGrowth:
        return [
          const _PreviewKpi('New Customers', '1,250', Icons.group_add_outlined, AppColors.primary),
          const _PreviewKpi('Churn Rate', '3.2%', Icons.person_remove_outlined, AppColors.danger),
          const _PreviewKpi('Retention', '78%', Icons.loyalty_outlined, AppColors.success),
          const _PreviewKpi('Avg LTV', 'ETB 8,400', Icons.star_outline, AppColors.warning),
        ];
      case ReportType.roiAnalysis:
        return [
          const _PreviewKpi('Overall ROI', '4.35×', Icons.trending_up_outlined, AppColors.primary),
          const _PreviewKpi('Total Revenue', 'ETB 3,262,500', Icons.attach_money_outlined, AppColors.success),
          const _PreviewKpi('Total Spend', 'ETB 750,000', Icons.money_off_outlined, AppColors.danger),
          const _PreviewKpi('Best Channel', 'Email', Icons.email_outlined, AppColors.info),
        ];
      case ReportType.communicationPerformance:
        return [
          const _PreviewKpi('Campaigns Sent', '60', Icons.send_outlined, AppColors.primary),
          const _PreviewKpi('Open Rate', '34.2%', Icons.mark_email_read_outlined, AppColors.success),
          const _PreviewKpi('CTR', '5.8%', Icons.ads_click_outlined, AppColors.info),
          const _PreviewKpi('Unsubscribe', '0.4%', Icons.unsubscribe_outlined, AppColors.warning),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _kpis(type);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 600 ? 4 : (w >= 340 ? 2 : 1);
      final gap = 12.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: kpis.map((k) => SizedBox(width: cardW, child: _PreviewKpiCard(kpi: k))).toList(),
      );
    });
  }
}

class _PreviewKpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _PreviewKpi(this.label, this.value, this.icon, this.color);
}

class _PreviewKpiCard extends StatelessWidget {
  final _PreviewKpi kpi;
  const _PreviewKpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(kpi.icon, size: 18, color: kpi.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kpi.value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(brightness)),
                    overflow: TextOverflow.ellipsis),
                Text(kpi.label,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary(brightness)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Preview section wrapper
class _PreviewSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _PreviewSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(brightness))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// Insight row
class _InsightRow extends StatelessWidget {
  final String text;
  const _InsightRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary(brightness),
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Preview Chart — pure-Flutter bar visualization (no external chart lib)
// Only rendered for report types where a visual adds genuine value.
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewChart extends StatelessWidget {
  final ReportType type;
  const _PreviewChart({required this.type});

  @override
  Widget build(BuildContext context) {
    final bars = _bars(type);
    final max = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: LayoutBuilder(builder: (context, constraints) {
        final barW =
            ((constraints.maxWidth - (bars.length - 1) * 8.0) / bars.length)
                .clamp(20.0, 64.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: bars.map((b) {
            final frac = max == 0 ? 0.0 : b.value / max;
            return _BarColumn(
              label: b.label,
              value: b.displayValue,
              heightFactor: frac,
              color: b.color,
              barWidth: barW,
            );
          }).toList(),
        );
      }),
    );
  }

  List<_BarData> _bars(ReportType t) {
    switch (t) {
      case ReportType.campaignPerformance:
        return [
          _BarData('Social', 45200, '45.2K', AppColors.primary),
          _BarData('Email', 28900, '28.9K', AppColors.info),
          _BarData('Paid', 22100, '22.1K', AppColors.success),
          _BarData('Retarget', 18700, '18.7K', AppColors.warning),
          _BarData('Influencer', 12000, '12.0K', AppColors.chartPalette[5]),
        ];
      case ReportType.roiAnalysis:
        return [
          _BarData('Retarget', 610, '6.1×', AppColors.primary),
          _BarData('Email', 580, '5.8×', AppColors.info),
          _BarData('Prod.Launch', 520, '5.2×', AppColors.success),
          _BarData('Brand', 480, '4.8×', AppColors.warning),
          _BarData('Influencer', 180, '1.8×', AppColors.danger),
        ];
      case ReportType.customerGrowth:
        return [
          _BarData('Jan', 180, '180', AppColors.primary),
          _BarData('Feb', 210, '210', AppColors.info),
          _BarData('Mar', 160, '160', AppColors.success),
          _BarData('Apr', 260, '260', AppColors.warning),
          _BarData('May', 310, '310', AppColors.primary),
          _BarData('Jun', 240, '240', AppColors.info),
        ];
      case ReportType.budgetReport:
        return [
          _BarData('Social', 85, '85%', AppColors.primary),
          _BarData('Email', 70, '70%', AppColors.info),
          _BarData('Paid Ads', 118, '118%', AppColors.danger),
          _BarData('Content', 60, '60%', AppColors.success),
          _BarData('Influencer', 76, '76%', AppColors.warning),
        ];
      default:
        return [];
    }
  }
}

class _BarData {
  final String label;
  final double value;
  final String displayValue;
  final Color color;
  const _BarData(this.label, this.value, this.displayValue, this.color);
}

class _BarColumn extends StatelessWidget {
  final String label;
  final String value;
  final double heightFactor; // 0.0 – 1.0
  final Color color;
  final double barWidth;

  const _BarColumn({
    required this.label,
    required this.value,
    required this.heightFactor,
    required this.color,
    this.barWidth = 40,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: AppConstants.animNormal,
          width: barWidth,
          height: (140 * heightFactor).clamp(4.0, 140.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: barWidth + 4,
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: textSec),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
