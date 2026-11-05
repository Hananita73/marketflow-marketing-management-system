import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/access_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Local mutable workflow model
// ─────────────────────────────────────────────────────────────────────────────

class _Workflow {
  String id;
  String name;
  String description;
  String trigger;
  String status;
  DateTime lastRun;
  DateTime? nextRun;
  int totalRuns;
  List<_WorkflowStep> steps;

  _Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    required this.status,
    required this.lastRun,
    this.nextRun,
    required this.totalRuns,
    required this.steps,
  });

  _Workflow copyWith({
    String? status,
    List<_WorkflowStep>? steps,
    String? name,
    String? description,
    String? trigger,
  }) => _Workflow(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    trigger: trigger ?? this.trigger,
    status: status ?? this.status,
    lastRun: lastRun,
    nextRun: nextRun,
    totalRuns: totalRuns,
    steps: steps ?? this.steps,
  );
}

class _WorkflowStep {
  String type; // 'trigger', 'condition', 'action', 'delay'
  String label;
  String description;

  _WorkflowStep({required this.type, required this.label, required this.description});
}

// Seed data
List<_Workflow> _seedWorkflows() => [
  _Workflow(
    id: 'WF001', name: 'New Lead Welcome Flow',
    description: 'Sends a welcome email to every new lead created in the system.',
    trigger: 'New Lead Created', status: AppConstants.statusActive,
    lastRun: DateTime(2026, 8, 14, 10, 30), nextRun: DateTime(2026, 8, 16, 10, 0),
    totalRuns: 1248,
    steps: [
      _WorkflowStep(type: 'trigger', label: 'New Lead Created',     description: 'Fires when a new lead is added'),
      _WorkflowStep(type: 'delay',   label: 'Wait 1 Day',           description: 'Pause for 24 hours'),
      _WorkflowStep(type: 'action',  label: 'Send Welcome Email',   description: 'Email: Welcome to MarketFlow'),
      _WorkflowStep(type: 'condition', label: 'Email Opened?',      description: 'Branch: email_opened = true'),
      _WorkflowStep(type: 'action',  label: 'Update Lead Status',   description: 'Set status → Contacted'),
    ],
  ),
  _Workflow(
    id: 'WF002', name: 'Purchase Follow-Up',
    description: 'Follows up with buyers after a completed order to collect reviews.',
    trigger: 'Order Completed', status: AppConstants.statusActive,
    lastRun: DateTime(2026, 8, 13, 15, 0), nextRun: DateTime(2026, 8, 20, 15, 0),
    totalRuns: 520,
    steps: [
      _WorkflowStep(type: 'trigger', label: 'Order Completed',      description: 'Fires when a purchase is confirmed'),
      _WorkflowStep(type: 'action',  label: 'Send Receipt Email',   description: 'Email: Order confirmation'),
      _WorkflowStep(type: 'delay',   label: 'Wait 7 Days',          description: 'Pause for 7 days'),
      _WorkflowStep(type: 'action',  label: 'Send Review Request',  description: 'Email: Please review your order'),
    ],
  ),
  _Workflow(
    id: 'WF003', name: 'Re-Engagement Campaign',
    description: 'Re-engages users who have been inactive for 90+ days with a win-back offer.',
    trigger: 'No Activity (90 Days)', status: AppConstants.statusPaused,
    lastRun: DateTime(2026, 7, 1, 9, 0), nextRun: null,
    totalRuns: 312,
    steps: [
      _WorkflowStep(type: 'trigger',   label: 'Inactive 90 Days',   description: 'Fires when last_activity > 90 days'),
      _WorkflowStep(type: 'action',    label: 'Send Win-Back Email', description: 'Email: We miss you + coupon'),
      _WorkflowStep(type: 'delay',     label: 'Wait 5 Days',         description: 'Pause for 5 days'),
      _WorkflowStep(type: 'condition', label: 'Responded?',          description: 'Branch: email_opened = true'),
      _WorkflowStep(type: 'action',    label: 'Update Status',       description: 'Set status → Re-engaged or Inactive'),
    ],
  ),
  _Workflow(
    id: 'WF004', name: 'Lead Score Qualifier',
    description: 'Notifies sales team and creates opportunity when a lead score reaches 80+.',
    trigger: 'Lead Score Updated', status: AppConstants.statusActive,
    lastRun: DateTime(2026, 8, 14, 8, 0), nextRun: DateTime(2026, 8, 15, 8, 0),
    totalRuns: 890,
    steps: [
      _WorkflowStep(type: 'trigger',   label: 'Score Updated',        description: 'Fires when lead_score changes'),
      _WorkflowStep(type: 'condition', label: 'Score ≥ 80?',          description: 'Branch: score >= 80'),
      _WorkflowStep(type: 'action',    label: 'Notify Sales Team',    description: 'Internal notification to team'),
      _WorkflowStep(type: 'action',    label: 'Create Opportunity',   description: 'Auto-create opportunity record'),
    ],
  ),
  _Workflow(
    id: 'WF005', name: 'Birthday Campaign',
    description: 'Sends a personalized birthday greeting with a special discount.',
    trigger: 'Customer Birthday', status: AppConstants.statusDraft,
    lastRun: DateTime(2026, 6, 1, 9, 0), nextRun: null,
    totalRuns: 0,
    steps: [
      _WorkflowStep(type: 'trigger', label: 'Birthday Today',      description: 'Fires on customer birthday'),
      _WorkflowStep(type: 'action',  label: 'Send Birthday Email', description: 'Email: Happy Birthday + 20% off'),
    ],
  ),
];

final List<_Workflow> _globalWorkflows = _seedWorkflows();
int _nextWfId = 6;

// ─────────────────────────────────────────────────────────────────────────────
// AutomationScreen
// ─────────────────────────────────────────────────────────────────────────────

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});
  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  final List<_Workflow> _workflows = List.from(_globalWorkflows);
  String _searchQuery = '';
  String _statusFilter = 'All';

  static const _statuses = ['All', 'Active', 'Paused', 'Draft', 'Failed'];

  @override
  void initState() {
    super.initState();
    _loadFromSupabase();
  }

  // ── Supabase persistence ──────────────────────────────────────────────────

  Future<void> _loadFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await Supabase.instance.client
          .from('automation_workflows')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 8));

      if ((rows as List).isNotEmpty) {
        final loaded = rows.map<_Workflow>(_workflowFromRow).toList();
        setState(() {
          _workflows
            ..clear()
            ..addAll(loaded);
        });
      } else {
        // Seed initial data on first run
        for (final wf in _globalWorkflows) {
          await _persistWorkflow(wf);
        }
      }
    } catch (_) {
      // Offline: keep in-memory seed data
    }
  }

  Future<void> _persistWorkflow(_Workflow wf) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.instance.client
          .from('automation_workflows')
          .upsert(_workflowToRow(wf))
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<void> _deleteFromSupabase(String id) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.instance.client
          .from('automation_workflows')
          .delete()
          .eq('id', id)
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Map<String, dynamic> _workflowToRow(_Workflow wf) => {
    'id': wf.id,
    'name': wf.name,
    'description': wf.description,
    'trigger_type': wf.trigger,
    'trigger_config': <String, dynamic>{},
    'status': wf.status,
    'run_count': wf.totalRuns,
    'last_run_at': wf.lastRun.toIso8601String(),
    'created_by': AuthService().currentName,
    'steps': wf.steps.map((s) => {
      'type': s.type, 'label': s.label, 'description': s.description,
    }).toList(),
  };

  _Workflow _workflowFromRow(Map<String, dynamic> r) {
    final steps = ((r['steps'] as List?) ?? []).map<_WorkflowStep>((s) {
      final m = s as Map<String, dynamic>;
      return _WorkflowStep(
        type: m['type']?.toString() ?? 'action',
        label: m['label']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
      );
    }).toList();
    return _Workflow(
      id: r['id']?.toString() ?? '',
      name: r['name']?.toString() ?? '',
      description: r['description']?.toString() ?? '',
      trigger: r['trigger_type']?.toString() ?? 'Manual',
      status: r['status']?.toString() ?? AppConstants.statusDraft,
      lastRun: DateTime.tryParse(r['last_run_at']?.toString() ?? '') ?? DateTime.now(),
      nextRun: null,
      totalRuns: (r['run_count'] as num?)?.toInt() ?? 0,
      steps: steps,
    );
  }

  List<_Workflow> get _filtered => _workflows.where((w) {
    final q = _searchQuery.toLowerCase();
    final matchQ = q.isEmpty ||
        w.name.toLowerCase().contains(q) ||
        w.trigger.toLowerCase().contains(q) ||
        w.description.toLowerCase().contains(q);
    final matchS = _statusFilter == 'All' || w.status == _statusFilter;
    return matchQ && matchS;
  }).toList();

  int get _activeCount => _workflows.where((w) => w.status == AppConstants.statusActive).length;
  int get _runsToday => _workflows
      .where((w) => w.lastRun.day == DateTime.now().day &&
          w.lastRun.month == DateTime.now().month)
      .fold(0, (s, w) => s + (w.totalRuns > 0 ? 12 : 0));
  int get _failedCount => _workflows.where((w) => w.status == 'Failed').length;
  String get _successRate {
    if (_workflows.isEmpty) return '100%';
    final active = _workflows.where((w) => w.status == AppConstants.statusActive).length;
    return '${(active / _workflows.length * 100).toStringAsFixed(0)}%';
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _togglePause(_Workflow wf) {
    if (!AccessService.canEdit('Automation')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your role does not have permission to modify workflows.'),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final updated = wf.copyWith(
      status: wf.status == AppConstants.statusActive
          ? AppConstants.statusPaused
          : AppConstants.statusActive,
    );
    setState(() {
      final idx = _workflows.indexWhere((w) => w.id == wf.id);
      if (idx != -1) _workflows[idx] = updated;
    });
    _persistWorkflow(updated);
    AuditLogService.log(
      action: updated.status == AppConstants.statusActive ? 'activate' : 'update',
      module: 'Automation', recordId: wf.id, recordName: wf.name,
    );
    _showSnack(wf.status == AppConstants.statusActive ? 'Workflow paused.' : 'Workflow resumed.');
  }

  void _duplicate(_Workflow wf) {
    if (!AccessService.requireCreate(context, 'Automation')) return;
    final copy = _Workflow(
      id: 'WF${(_nextWfId++).toString().padLeft(3, '0')}',
      name: '${wf.name} (Copy)',
      description: wf.description,
      trigger: wf.trigger,
      status: AppConstants.statusDraft,
      lastRun: DateTime.now(),
      nextRun: null,
      totalRuns: 0,
      steps: List.from(wf.steps),
    );
    setState(() => _workflows.add(copy));
    _persistWorkflow(copy);
    _showSnack('Workflow duplicated as draft.');
  }

  void _confirmDelete(_Workflow wf) {
    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(brightness),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              side: BorderSide(color: AppTheme.border(brightness))),
          title: const Text('Delete Workflow',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          content: Text('Delete "${wf.name}"? This cannot be undone.',
              style: TextStyle(color: AppTheme.textSecondary(brightness))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                if (!AccessService.requireDelete(context, 'Automation')) return;
                setState(() => _workflows.removeWhere((w) => w.id == wf.id));
                _deleteFromSupabase(wf.id);
                AuditLogService.logDelete('Automation', wf.id, wf.name);
                Navigator.pop(ctx);
                _showSnack('Workflow deleted.');
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openBuilder({_Workflow? existing}) {
    final isEdit = existing != null;
    if (!AccessService.requireSave(context, isEdit, 'Automation')) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WorkflowBuilderDialog(
        existing: existing,
        onSave: (wf) {
          setState(() {
            if (existing != null) {
              final idx = _workflows.indexWhere((w) => w.id == wf.id);
              if (idx != -1) _workflows[idx] = wf;
            } else {
              _workflows.add(wf);
            }
          });
          _persistWorkflow(wf);
          AuditLogService.log(
            action: existing != null ? 'update' : 'create',
            module: 'Automation', recordId: wf.id, recordName: wf.name,
          );
          _showSnack(existing != null ? 'Workflow updated.' : 'Workflow created.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered   = _filtered;

    return CustomScrollView(
      slivers: [
        // ── Sticky header ─────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _AutomationHeaderDelegate(
            onCreateWorkflow: () {
              if (!AccessService.requireCreate(context, 'Automation')) return;
              _openBuilder();
            },
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AutomationStatsRow(
                activeCount: _activeCount,
                runsToday: _runsToday,
                successRate: _successRate,
                failedCount: _failedCount,
              ),
              const SizedBox(height: AppConstants.sectionSpacing),
              _WorkflowListSection(
                workflows: filtered,
                searchQuery: _searchQuery,
                statusFilter: _statusFilter,
                statuses: _statuses,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onStatusChanged: (v) => setState(() => _statusFilter = v),
                onEdit: (wf) => _openBuilder(existing: wf),
                onDelete: _confirmDelete,
                onTogglePause: _togglePause,
                onDuplicate: _duplicate,
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky header delegate
// ─────────────────────────────────────────────────────────────────────────────

class _AutomationHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onCreateWorkflow;
  final Brightness brightness;

  const _AutomationHeaderDelegate({
    required this.onCreateWorkflow,
    required this.brightness,
  });

  static const double _height = 72.0;

  @override double get minExtent => _height;
  @override double get maxExtent => _height;

  @override
  bool shouldRebuild(_AutomationHeaderDelegate old) =>
      old.brightness != brightness || old.onCreateWorkflow != onCreateWorkflow;

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
        child: _AutomationPageHeader(onCreateWorkflow: onCreateWorkflow),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Header
// ─────────────────────────────────────────────────────────────────────────────

class _AutomationPageHeader extends StatelessWidget {
  final VoidCallback onCreateWorkflow;
  const _AutomationPageHeader({required this.onCreateWorkflow});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (_, constraints) {
      final narrow = constraints.maxWidth < 600;

      final titleBlock = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: const Icon(Icons.settings_suggest_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Automation',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Build and manage automated marketing workflows.',
                  style: TextStyle(color: textSec, fontSize: 12)),
            ],
          ),
        ],
      );

      final btn = ElevatedButton.icon(
        onPressed: onCreateWorkflow,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Create Workflow'),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      );

      if (narrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          titleBlock, const SizedBox(height: 8), btn,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        titleBlock, const Spacer(), btn,
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _AutomationStatsRow extends StatelessWidget {
  final int activeCount;
  final int runsToday;
  final String successRate;
  final int failedCount;
  const _AutomationStatsRow({required this.activeCount, required this.runsToday,
      required this.successRate, required this.failedCount});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cards = [
      _AutoStatCard(label: 'Active Workflows', value: '$activeCount',
          icon: Icons.play_circle_outline,  iconColor: AppColors.success,
          iconBg: AppTheme.successBg(brightness)),
      _AutoStatCard(label: 'Runs Today',       value: '$runsToday',
          icon: Icons.refresh_outlined,      iconColor: AppColors.primary,
          iconBg: AppTheme.primaryLighter(brightness)),
      _AutoStatCard(label: 'Success Rate',     value: successRate,
          icon: Icons.check_circle_outline,  iconColor: AppColors.info,
          iconBg: AppTheme.infoBg(brightness)),
      _AutoStatCard(label: 'Failed Runs',      value: '$failedCount',
          icon: Icons.error_outline,         iconColor: AppColors.danger,
          iconBg: AppTheme.dangerBg(brightness)),
    ];
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 900 ? 4 : w >= 600 ? 2 : 1;
      final cardWidth = (w - (cols - 1) * AppConstants.itemSpacing) / cols;
      return Wrap(
        spacing: AppConstants.itemSpacing,
        runSpacing: AppConstants.itemSpacing,
        children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    });
  }
}

class _AutoStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  const _AutoStatCard({required this.label, required this.value, required this.icon,
      required this.iconColor, required this.iconBg});

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
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(brightness))),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Workflow List Section
// ─────────────────────────────────────────────────────────────────────────────

class _WorkflowListSection extends StatelessWidget {
  final List<_Workflow> workflows;
  final String searchQuery;
  final String statusFilter;
  final List<String> statuses;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<_Workflow> onEdit;
  final ValueChanged<_Workflow> onDelete;
  final ValueChanged<_Workflow> onTogglePause;
  final ValueChanged<_Workflow> onDuplicate;

  const _WorkflowListSection({
    required this.workflows,
    required this.searchQuery,
    required this.statusFilter,
    required this.statuses,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final inputFill  = AppTheme.inputFill(brightness);

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Workflows',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPri)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, bc) {
          final searchField = SizedBox(
            height: 38,
            child: TextField(
              onChanged: onSearchChanged,
              style: TextStyle(fontSize: 13, color: textPri),
              decoration: InputDecoration(
                hintText: 'Search workflows…',
                hintStyle: TextStyle(fontSize: 13, color: textSec),
                prefixIcon: Icon(Icons.search, size: 18, color: textSec),
                filled: true, fillColor: inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: BorderSide(color: borderCol)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: BorderSide(color: borderCol)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          );
          final statFilter = SizedBox(
            height: 38,
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: statusFilter,
              dropdownColor: cardBg,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: BorderSide(color: borderCol)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: BorderSide(color: borderCol)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                filled: true, fillColor: inputFill,
              ),
              style: TextStyle(fontSize: 13, color: textPri),
              icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textSec),
              items: statuses.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: TextStyle(color: textPri)))).toList(),
              onChanged: (v) { if (v != null) onStatusChanged(v); },
            ),
          );
          if (bc.maxWidth < 500) {
            return Column(children: [
              searchField, const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: statFilter),
            ]);
          }
          return Row(children: [
            Expanded(child: searchField), const SizedBox(width: 8), statFilter,
          ]);
        }),
        const SizedBox(height: 12),
        if (workflows.isEmpty)
          _AutoEmptyState()
        else
          ...workflows.map((wf) => _WorkflowCard(
            workflow: wf,
            onEdit: onEdit,
            onDelete: onDelete,
            onTogglePause: onTogglePause,
            onDuplicate: onDuplicate,
          )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Workflow Card
// ─────────────────────────────────────────────────────────────────────────────

class _WorkflowCard extends StatelessWidget {
  final _Workflow workflow;
  final ValueChanged<_Workflow> onEdit;
  final ValueChanged<_Workflow> onDelete;
  final ValueChanged<_Workflow> onTogglePause;
  final ValueChanged<_Workflow> onDuplicate;

  const _WorkflowCard({
    required this.workflow,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePause,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgFill      = AppTheme.backgroundFill(brightness);
    final borderCol   = AppTheme.border(brightness);
    final textPri     = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final wf          = workflow;
    final statusColor = _wfStatusColor(wf.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderCol),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 10, height: 10, margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wf.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
              const SizedBox(height: 2),
              Text(wf.description, style: TextStyle(fontSize: 12, color: textSec),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 12),
          _WfStatusBadge(status: wf.status),
        ]),
        const SizedBox(height: 12),
        _MiniWorkflowFlow(steps: wf.steps),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, bc) {
          final narrow = bc.maxWidth < 500;
          final metaItems = Wrap(spacing: 16, runSpacing: 6, children: [
            _MetaChip(icon: Icons.bolt_outlined,        label: wf.trigger,      textSec: textSec),
            _MetaChip(icon: Icons.play_arrow_outlined,  label: '${wf.totalRuns} runs', textSec: textSec),
            _MetaChip(icon: Icons.access_time_outlined,
                label: 'Last: ${wf.lastRun.day}/${wf.lastRun.month}/${wf.lastRun.year}', textSec: textSec),
            if (wf.nextRun != null)
              _MetaChip(icon: Icons.schedule_outlined,
                  label: 'Next: ${wf.nextRun!.day}/${wf.nextRun!.month}/${wf.nextRun!.year}',
                  textSec: textSec),
          ]);
          final actions = Wrap(spacing: 8, runSpacing: 4, children: [
            _WfActionBtn(icon: Icons.edit_outlined,     label: 'Edit',      onTap: () => onEdit(wf)),
            _WfActionBtn(
              icon: wf.status == AppConstants.statusActive ? Icons.pause_outlined : Icons.play_arrow_outlined,
              label: wf.status == AppConstants.statusActive ? 'Pause' : 'Resume',
              onTap: () => onTogglePause(wf),
              color: wf.status == AppConstants.statusActive ? AppColors.warning : AppColors.success,
            ),
            _WfActionBtn(icon: Icons.copy_outlined,     label: 'Duplicate', onTap: () => onDuplicate(wf)),
            _WfActionBtn(icon: Icons.delete_outline,    label: 'Delete',    onTap: () => onDelete(wf),
                color: AppColors.danger),
          ]);
          if (narrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              metaItems, const SizedBox(height: 10), actions,
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: metaItems), const SizedBox(width: 12), actions,
          ]);
        }),
      ]),
    );
  }
}

class _MiniWorkflowFlow extends StatelessWidget {
  final List<_WorkflowStep> steps;
  const _MiniWorkflowFlow({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final textSec = AppTheme.textSecondary(Theme.of(context).brightness);
    final borderCol = AppTheme.border(Theme.of(context).brightness);

    return LayoutBuilder(builder: (_, bc) {
      final narrow = bc.maxWidth < 500;
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(steps.length, (i) {
            final isLast = i == steps.length - 1;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _StepChip(step: steps[i]),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(children: [
                    Container(width: 1, height: 8, color: borderCol),
                    Icon(Icons.keyboard_arrow_down, size: 12, color: textSec),
                    Container(width: 1, height: 4, color: borderCol),
                  ]),
                ),
            ]);
          }),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14, color: textSec),
              );
            }
            return _StepChip(step: steps[i ~/ 2]);
          }),
        ),
      );
    });
  }
}

class _StepChip extends StatelessWidget {
  final _WorkflowStep step;
  const _StepChip({required this.step});

  Color get _color {
    switch (step.type) {
      case 'trigger':   return AppColors.primary;
      case 'condition': return AppColors.warning;
      case 'action':    return AppColors.success;
      case 'delay':     return AppColors.textSecondary;
      default:          return AppColors.info;
    }
  }

  IconData get _icon {
    switch (step.type) {
      case 'trigger':   return Icons.bolt_outlined;
      case 'condition': return Icons.help_outline;
      case 'action':    return Icons.check_circle_outline;
      case 'delay':     return Icons.hourglass_empty_outlined;
      default:          return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: step.description,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 12, color: _color),
        const SizedBox(width: 4),
        Text(step.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _color),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Workflow Builder Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _WorkflowBuilderDialog extends StatefulWidget {
  final _Workflow? existing;
  final ValueChanged<_Workflow> onSave;
  const _WorkflowBuilderDialog({this.existing, required this.onSave});

  @override
  State<_WorkflowBuilderDialog> createState() => _WorkflowBuilderDialogState();
}

class _WorkflowBuilderDialogState extends State<_WorkflowBuilderDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late String _trigger;
  late String _status;
  late List<_WorkflowStep> _steps;
  final _formKey = GlobalKey<FormState>();

  static const _triggers = [
    'New Lead Created', 'Order Completed', 'No Activity (90 Days)',
    'Lead Score Updated', 'Customer Birthday', 'Campaign Started', 'Form Submitted',
  ];

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _descCtrl = TextEditingController(text: w?.description ?? '');
    _trigger  = w?.trigger ?? _triggers[0];
    _status   = w?.status  ?? AppConstants.statusDraft;
    _steps    = w != null ? List.from(w.steps) : [
      _WorkflowStep(type: 'trigger', label: _triggers[0], description: 'Trigger event'),
    ];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addStep(String type) {
    String label, description;
    switch (type) {
      case 'condition': label = 'New Condition'; description = 'Define a branch condition'; break;
      case 'action':    label = 'New Action';    description = 'Define what action to take'; break;
      case 'delay':     label = 'Wait 1 Day';    description = 'Pause for 24 hours'; break;
      default:          label = 'New Step';      description = '';
    }
    setState(() => _steps.add(_WorkflowStep(type: type, label: label, description: description)));
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() => _steps.removeAt(index));
  }

  void _editStep(int index) {
    final step = _steps[index];
    final labelCtrl = TextEditingController(text: step.label);
    final descCtrl  = TextEditingController(text: step.description);
    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(brightness),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              side: BorderSide(color: AppTheme.border(brightness))),
          title: Text('Edit Step',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(brightness))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: labelCtrl,
                style: TextStyle(color: AppTheme.textPrimary(brightness)),
                decoration: InputDecoration(
                    labelText: 'Label',
                    labelStyle: TextStyle(color: AppTheme.textSecondary(brightness)))),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2,
                style: TextStyle(color: AppTheme.textPrimary(brightness)),
                decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: AppTheme.textSecondary(brightness)))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _steps[index] = _WorkflowStep(
                    type: step.type,
                    label: labelCtrl.text.trim().isEmpty ? step.label : labelCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit     = widget.existing != null;
    final brightness = Theme.of(context).brightness;
    final dialogBg   = AppTheme.surfaceColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final inputFill  = AppTheme.inputFill(brightness);
    final priLighter = AppTheme.primaryLighter(brightness);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          side: BorderSide(color: borderCol)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(children: [
          // Dialog header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: priLighter,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                child: const Icon(Icons.settings_suggest_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Workflow' : 'Create Workflow',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPri)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: textSec),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Divider(height: 1, color: AppTheme.divider(brightness)),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _AutoFormLabel('Workflow Name *', textPri),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(fontSize: 13, color: textPri),
                    decoration: _autoInputDec('e.g. New Lead Welcome Flow', inputFill, borderCol, textSec),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _AutoFormLabel('Description', textPri),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    style: TextStyle(fontSize: 13, color: textPri),
                    decoration: _autoInputDec('What does this workflow do?', inputFill, borderCol, textSec),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (_, bc) {
                    final narrow = bc.maxWidth < 420;
                    final triggerField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _AutoFormLabel('Trigger', textPri),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _trigger,
                        dropdownColor: dialogBg,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              borderSide: BorderSide(color: borderCol)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              borderSide: BorderSide(color: borderCol)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                          filled: true, fillColor: inputFill,
                        ),
                        style: TextStyle(fontSize: 13, color: textPri),
                        icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textSec),
                        items: _triggers.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textPri)))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                            _trigger = v;
                            if (_steps.isNotEmpty && _steps[0].type == 'trigger') {
                              _steps[0] = _WorkflowStep(
                                  type: 'trigger', label: v, description: _steps[0].description);
                            }
                          });
                          }
                        },
                      ),
                    ]);
                    final statusField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _AutoFormLabel('Status', textPri),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        dropdownColor: dialogBg,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              borderSide: BorderSide(color: borderCol)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              borderSide: BorderSide(color: borderCol)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                          filled: true, fillColor: inputFill,
                        ),
                        style: TextStyle(fontSize: 13, color: textPri),
                        icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textSec),
                        items: ['Draft', 'Active', 'Paused'].map((s) =>
                            DropdownMenuItem(value: s,
                                child: Text(s, style: TextStyle(color: textPri)))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _status = v); },
                      ),
                    ]);
                    if (narrow) return Column(children: [triggerField, const SizedBox(height: 14), statusField]);
                    return Row(children: [
                      Expanded(child: triggerField), const SizedBox(width: 12), Expanded(child: statusField),
                    ]);
                  }),
                  const SizedBox(height: 20),
                  Row(children: [
                    Text('Workflow Steps',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
                    const Spacer(),
                    Text('${_steps.length} steps',
                        style: TextStyle(fontSize: 12, color: textSec)),
                  ]),
                  const SizedBox(height: 10),
                  ..._buildStepList(borderCol, textPri, textSec),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _AddStepButton(label: 'Add Condition', icon: Icons.help_outline,
                        color: AppColors.warning,       onTap: () => _addStep('condition')),
                    _AddStepButton(label: 'Add Action',    icon: Icons.check_circle_outline,
                        color: AppColors.success,       onTap: () => _addStep('action')),
                    _AddStepButton(label: 'Add Delay',     icon: Icons.hourglass_empty_outlined,
                        color: AppColors.textSecondary, onTap: () => _addStep('delay')),
                  ]),
                ]),
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(height: 1, color: AppTheme.divider(brightness)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final wf = _Workflow(
                    id: widget.existing?.id ??
                        'WF${(_nextWfId++).toString().padLeft(3, '0')}',
                    name: _nameCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                    trigger: _trigger,
                    status: _status,
                    lastRun: widget.existing?.lastRun ?? DateTime.now(),
                    nextRun: widget.existing?.nextRun,
                    totalRuns: widget.existing?.totalRuns ?? 0,
                    steps: _steps,
                  );
                  Navigator.pop(context);
                  widget.onSave(wf);
                },
                child: Text(isEdit ? 'Save Changes' : 'Create Workflow'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildStepList(Color borderCol, Color textPri, Color textSec) {
    return List.generate(_steps.length, (i) {
      final step    = _steps[i];
      final isFirst = i == 0;
      final color   = _stepColor(step.type);
      final icon    = _stepIcon(step.type);

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isFirst)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Column(children: [
              Container(width: 1, height: 12, color: borderCol),
              Icon(Icons.keyboard_arrow_down, size: 12, color: textSec),
            ]),
          ),
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundFill(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: borderCol),
              ),
              child: Row(children: [
                Container(width: 4, height: 16,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(step.label, style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500, color: textPri)),
                    if (step.description.isNotEmpty)
                      Text(step.description, style: TextStyle(fontSize: 11, color: textSec)),
                  ]),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 15, color: textSec),
                  onPressed: () => _editStep(i),
                  tooltip: 'Edit step',
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                if (!isFirst)
                  IconButton(
                    icon: const Icon(Icons.close, size: 15, color: AppColors.danger),
                    onPressed: () => _removeStep(i),
                    tooltip: 'Remove step',
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 4),
      ]);
    });
  }

  Color _stepColor(String type) {
    switch (type) {
      case 'trigger':   return AppColors.primary;
      case 'condition': return AppColors.warning;
      case 'action':    return AppColors.success;
      case 'delay':     return AppColors.textSecondary;
      default:          return AppColors.info;
    }
  }

  IconData _stepIcon(String type) {
    switch (type) {
      case 'trigger':   return Icons.bolt_outlined;
      case 'condition': return Icons.help_outline;
      case 'action':    return Icons.check_circle_outline;
      case 'delay':     return Icons.hourglass_empty_outlined;
      default:          return Icons.circle_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _wfStatusColor(String status) {
  switch (status) {
    case AppConstants.statusActive:  return AppColors.success;
    case AppConstants.statusPaused:  return AppColors.warning;
    case AppConstants.statusDraft:   return AppColors.textSecondary;
    case 'Failed':                   return AppColors.danger;
    default:                         return AppColors.textSecondary;
  }
}

class _WfStatusBadge extends StatelessWidget {
  final String status;
  const _WfStatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _wfStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textSec;
  const _MetaChip({required this.icon, required this.label, required this.textSec});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: textSec),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: textSec)),
  ]);
}

class _WfActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _WfActionBtn({required this.icon, required this.label,
      required this.onTap, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

class _AddStepButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AddStepButton({required this.label, required this.icon,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14, color: color),
    label: Text(label, style: TextStyle(fontSize: 12, color: color)),
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

class _AutoEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Icon(Icons.settings_suggest_outlined, size: 40,
            color: AppTheme.textSecondary(brightness).withValues(alpha: 0.35)),
        const SizedBox(height: 12),
        Text('No workflows found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(brightness))),
        const SizedBox(height: 4),
        Text('Create your first workflow or clear your filters.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
      ]),
    );
  }
}

class _AutoFormLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _AutoFormLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color));
}

InputDecoration _autoInputDec(
    String hint, Color fillColor, Color borderColor, Color hintColor) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: hintColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      filled: true,
      fillColor: fillColor,
    );
