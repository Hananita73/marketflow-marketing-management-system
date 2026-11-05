// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/content_item.dart';
import '../../widgets/badges/status_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Display helpers — maps stored status constants to human labels and vice-versa
// Published  → statusActive
// Scheduled  → statusPaused
// Draft      → statusDraft
// Archived   → statusCompleted
// ─────────────────────────────────────────────────────────────────────────────
const _statusLabels = {
  AppConstants.statusActive:    'Published',
  AppConstants.statusPaused:    'Scheduled',
  AppConstants.statusDraft:     'Draft',
  AppConstants.statusCompleted: 'Archived',
};

const _labelToStatus = {
  'Published': AppConstants.statusActive,
  'Scheduled': AppConstants.statusPaused,
  'Draft':     AppConstants.statusDraft,
  'Archived':  AppConstants.statusCompleted,
};

const List<String> _contentTypes = [
  'All', 'Blog Post', 'Video', 'Social Post', 'Email', 'Infographic', 'Webinar',
];

const List<String> _statusFilterLabels = [
  'All', 'Published', 'Scheduled', 'Draft', 'Archived',
];

const List<String> _sortOptions = [
  'Newest', 'Oldest', 'Title A–Z', 'Most Views', 'Most Clicks',
];

// ─────────────────────────────────────────────────────────────────────────────
// ContentScreen
// ─────────────────────────────────────────────────────────────────────────────
class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});
  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  // Data source: ContentRepository (Supabase-backed). The local copy below is
  // rebuilt via [_reload] after every mutation so setState picks up changes
  // made through [ContentRepository].
  List<ContentItem> _items = List.from(ContentRepository.getAll());

  void _reload() => _items = List.from(ContentRepository.getAll());

  // ── filter state ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _typeFilter    = 'All';
  String _statusFilter  = 'All';
  String _campaignFilter = 'All';
  String _sortBy        = 'Newest';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── computed list ─────────────────────────────────────────────────────────
  List<ContentItem> get _filtered {
    var list = List<ContentItem>.from(_items);
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) =>
          c.title.toLowerCase().contains(q) ||
          c.creator.toLowerCase().contains(q) ||
          c.campaignName.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q)).toList();
    }
    if (_typeFilter != 'All') {
      list = list.where((c) => c.type == _typeFilter).toList();
    }
    if (_statusFilter != 'All') {
      final s = _labelToStatus[_statusFilter] ?? _statusFilter;
      list = list.where((c) => c.status == s).toList();
    }
    if (_campaignFilter != 'All') {
      list = list.where((c) => c.campaignName == _campaignFilter).toList();
    }
    switch (_sortBy) {
      case 'Oldest':
        list.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        break;
      case 'Title A–Z':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Most Views':
        list.sort((a, b) => b.views.compareTo(a.views));
        break;
      case 'Most Clicks':
        list.sort((a, b) => b.clicks.compareTo(a.clicks));
        break;
      default: // Newest
        list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    }
    return list;
  }

  List<String> get _allCampaigns {
    final names = _items.map((c) => c.campaignName).where((n) => n != '—').toSet().toList()..sort();
    return ['All', ...names];
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  void _showCreateForm()               => _openForm(existing: null);
  void _showEditForm(ContentItem item) => _openForm(existing: item);

  void _duplicateItem(ContentItem item) {
    final copy = ContentItem(
      id: ContentRepository.nextId(),
      title: '${item.title} (Copy)',
      type: item.type,
      channel: item.channel,
      creator: item.creator,
      status: AppConstants.statusDraft,
      scheduledDate: item.scheduledDate,
      campaignName: item.campaignName,
      description: item.description,
      views: 0,
      clicks: 0,
    );
    if (!AccessService.requireCreate(context, 'Content')) return;
    setState(() {
      ContentRepository.add(copy);
      _reload();
    });
    _snack('Content duplicated as draft');
  }

  void _confirmDelete(ContentItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        final br = Theme.of(ctx).brightness;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(br),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLarge)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerBg(br),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Delete Content',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
          ]),
          content: Text('Delete "${item.title}"? This action cannot be undone.',
              style: TextStyle(color: AppTheme.textPrimary(br), fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                if (!AccessService.requireDelete(context, 'Content')) return;
                ContentRepository.remove(item.id);
                setState(_reload);
                Navigator.pop(ctx);
                _snack('Content deleted');
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }


  // ── Create / Edit form dialog ─────────────────────────────────────────────
  void _openForm({ContentItem? existing}) {
    final isEdit     = existing != null;
    final titleCtrl  = TextEditingController(text: existing?.title ?? '');
    final descCtrl   = TextEditingController(text: existing?.description ?? '');
    final bodyCtrl   = TextEditingController(text: existing?.description ?? '');
    final authorCtrl = TextEditingController(text: existing?.creator ?? 'Hana Tsegaye');
    final channelCtrl = TextEditingController(text: existing?.channel ?? '');
    final campaignCtrl = TextEditingController(text: existing?.campaignName ?? '');
    final tagsCtrl   = TextEditingController();
    String type     = existing?.type ?? 'Blog Post';
    String statusKey = existing?.status ?? AppConstants.statusDraft;
    DateTime schedDate = existing?.scheduledDate ?? DateTime.now();
    final formKey   = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final br          = Theme.of(ctx).brightness;
          final surfColor   = AppTheme.surfaceColor(br);
          final borderColor = AppTheme.border(br);
          final textPrimary = AppTheme.textPrimary(br);
          final textSec     = AppTheme.textSecondary(br);
          final inputFill   = AppTheme.inputFill(br);
          final surfVar     = AppTheme.surfaceVariant(br);

          return Dialog(
            backgroundColor: surfColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── dialog header ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLighter(br),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                          color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(isEdit ? 'Edit Content' : 'Create Content',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: textSec),
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                  ),
                  Divider(height: 24, color: borderColor),

                  // ── form body ──────────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // title
                            _FLabel('Content Title *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: titleCtrl,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _dec('e.g. How to Grow on Instagram in 2026', br),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),

                            // type + status row
                            _RowOrCol(
                              left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _FLabel('Content Type'),
                                const SizedBox(height: 6),
                                _DField(
                                  value: type,
                                  items: const ['Blog Post', 'Video', 'Social Post', 'Email', 'Infographic', 'Webinar'],
                                  br: br,
                                  onChanged: (v) => setLocal(() => type = v),
                                ),
                              ]),
                              right: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _FLabel('Status'),
                                const SizedBox(height: 6),
                                _DField(
                                  value: _statusLabels[statusKey] ?? statusKey,
                                  items: ['Published', 'Scheduled', 'Draft', 'Archived'],
                                  br: br,
                                  onChanged: (v) => setLocal(() => statusKey = _labelToStatus[v] ?? AppConstants.statusDraft),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 14),

                            // author + channel row
                            _RowOrCol(
                              left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _FLabel('Author'),
                                const SizedBox(height: 6),
                                TextFormField(controller: authorCtrl, style: TextStyle(fontSize: 13, color: textPrimary), decoration: _dec('Author name', br)),
                              ]),
                              right: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _FLabel('Channel / Platform'),
                                const SizedBox(height: 6),
                                TextFormField(controller: channelCtrl, style: TextStyle(fontSize: 13, color: textPrimary), decoration: _dec('e.g. Instagram', br)),
                              ]),
                            ),
                            const SizedBox(height: 14),

                            // campaign + schedule row
                            _RowOrCol(
                              left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _FLabel('Campaign'),
                                const SizedBox(height: 6),
                                TextFormField(controller: campaignCtrl, style: TextStyle(fontSize: 13, color: textPrimary), decoration: _dec('Campaign name', br)),
                              ]),
                              right: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _FLabel('Schedule Date'),
                                const SizedBox(height: 6),
                                InkWell(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: ctx,
                                      initialDate: schedDate,
                                      firstDate: DateTime(2024),
                                      lastDate: DateTime(2030),
                                      builder: (c, child) => Theme(
                                        data: Theme.of(c).copyWith(colorScheme: Theme.of(c).colorScheme.copyWith(primary: AppColors.primary)),
                                        child: child!,
                                      ),
                                    );
                                    if (d != null) setLocal(() => schedDate = d);
                                  },
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: inputFill,
                                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.calendar_today_outlined, size: 15, color: textSec),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${schedDate.day}/${schedDate.month}/${schedDate.year}',
                                        style: TextStyle(fontSize: 13, color: textPrimary),
                                      ),
                                    ]),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 14),

                            // description
                            _FLabel('Description'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: descCtrl,
                              maxLines: 2,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _dec('Brief description or summary…', br),
                            ),
                            const SizedBox(height: 14),

                            // content body
                            _FLabel('Content Body'),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // mini toolbar
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: surfVar,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMedium)),
                                    border: Border(bottom: BorderSide(color: borderColor)),
                                  ),
                                  child: Wrap(spacing: 2, children: [
                                    for (final lbl in ['B', 'I', 'U', '•', '1.', 'Link'])
                                      _MiniTb(label: lbl, textSec: textSec),
                                  ]),
                                ),
                                TextFormField(
                                  controller: bodyCtrl,
                                  maxLines: 5,
                                  style: TextStyle(fontSize: 13, color: textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'Write your content here…',
                                    hintStyle: TextStyle(fontSize: 13, color: textSec),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 14),

                            // media upload area
                            _FLabel('Media'),
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              onTap: () => _snack('Media upload coming soon'),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: inputFill,
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                  border: Border.all(color: borderColor, style: BorderStyle.solid),
                                ),
                                child: Column(children: [
                                  Icon(Icons.upload_file_outlined, size: 24, color: textSec),
                                  const SizedBox(height: 6),
                                  Text('Click to upload media', style: TextStyle(fontSize: 12, color: textSec)),
                                  Text('PNG, JPG, MP4, PDF up to 50 MB', style: TextStyle(fontSize: 11, color: textSec)),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // tags
                            _FLabel('Tags'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: tagsCtrl,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _dec('Add tags separated by commas…', br),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── footer actions ─────────────────────────────────────
                  Divider(height: 1, color: borderColor),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      OutlinedButton(
                        onPressed: () {
                          // save as draft
                          setLocal(() => statusKey = AppConstants.statusDraft);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary(br),
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save Draft', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(isEdit ? Icons.save_outlined : Icons.send_rounded, size: 15),
                        label: Text(isEdit ? 'Save Changes' : 'Publish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final saved = ContentItem(
                            id: isEdit ? existing.id : ContentRepository.nextId(),
                            title: titleCtrl.text.trim(),
                            type: type,
                            channel: channelCtrl.text.trim().isEmpty ? '—' : channelCtrl.text.trim(),
                            creator: authorCtrl.text.trim().isEmpty ? 'Hana Tsegaye' : authorCtrl.text.trim(),
                            status: statusKey,
                            scheduledDate: schedDate,
                            campaignName: campaignCtrl.text.trim().isEmpty ? '—' : campaignCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty ? bodyCtrl.text.trim() : descCtrl.text.trim(),
                            views: isEdit ? existing.views : 0,
                            clicks: isEdit ? existing.clicks : 0,
                          );
                          if (!AccessService.requireSave(context, isEdit, 'Content')) return;
                          setState(() {
                            if (isEdit) {
                              ContentRepository.update(saved);
                            } else {
                              ContentRepository.add(saved);
                            }
                            _reload();
                          });
                          Navigator.pop(ctx);
                          _snack(isEdit ? 'Content updated' : 'Content created');
                        },
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ── View detail dialog ────────────────────────────────────────────────────
  void _showDetail(ContentItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        final br          = Theme.of(ctx).brightness;
        final surfColor   = AppTheme.surfaceColor(br);
        final borderColor = AppTheme.border(br);
        final textPrimary = AppTheme.textPrimary(br);
        final textSec     = AppTheme.textSecondary(br);
        final surfVar     = AppTheme.surfaceVariant(br);

        return Dialog(
          backgroundColor: surfColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: item.typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.typeIcon, color: item.typeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item.title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary))),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: textSec),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // meta chips
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _TypeBadge(type: item.type),
                    StatusBadge(status: item.status),
                  ]),
                  const SizedBox(height: 16),
                  Divider(color: borderColor),
                  const SizedBox(height: 12),

                  // detail rows
                  _DRow(icon: Icons.person_outline_rounded, label: 'Author', value: item.creator, textSec: textSec, textPrimary: textPrimary),
                  _DRow(icon: Icons.campaign_outlined, label: 'Campaign', value: item.campaignName, textSec: textSec, textPrimary: textPrimary),
                  _DRow(icon: Icons.share_outlined, label: 'Channel', value: item.channel, textSec: textSec, textPrimary: textPrimary),
                  _DRow(icon: Icons.calendar_today_outlined, label: 'Scheduled', value: _fmtDate(item.scheduledDate), textSec: textSec, textPrimary: textPrimary),
                  _DRow(icon: Icons.visibility_outlined, label: 'Views', value: _fmtNum(item.views), textSec: textSec, textPrimary: textPrimary),
                  _DRow(icon: Icons.touch_app_outlined, label: 'Clicks', value: _fmtNum(item.clicks), textSec: textSec, textPrimary: textPrimary),

                  const SizedBox(height: 12),
                  Divider(color: borderColor),
                  const SizedBox(height: 12),

                  // content preview
                  Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfVar,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    child: Text(item.description.isEmpty ? 'No description provided.' : item.description,
                        style: TextStyle(fontSize: 13, color: textPrimary, height: 1.5)),
                  ),
                  const SizedBox(height: 20),

                  // actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _duplicateItem(item); },
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      label: const Text('Duplicate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _confirmDelete(item); },
                      icon: const Icon(Icons.delete_outline_rounded, size: 14),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _showEditForm(item); },
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Import dialog (stub) ──────────────────────────────────────────────────
  void _showImport() {
    final br = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) {
        final surf = AppTheme.surfaceColor(br);
        final textP = AppTheme.textPrimary(br);
        final textS = AppTheme.textSecondary(br);
        final bord  = AppTheme.border(br);
        return Dialog(
          backgroundColor: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primaryLighter(br), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.upload_file_outlined, color: AppColors.primary, size: 20)),
                  const SizedBox(width: 12),
                  Text('Import Content', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textP)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.close, size: 18, color: textS), onPressed: () => Navigator.pop(ctx), visualDensity: VisualDensity.compact),
                ]),
                Divider(height: 24, color: bord),
                InkWell(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill(br),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      border: Border.all(color: bord),
                    ),
                    child: Column(children: [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: textS),
                      const SizedBox(height: 8),
                      Text('Drop your CSV or JSON file here', style: TextStyle(fontSize: 13, color: textP, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('or click to browse', style: TextStyle(fontSize: 12, color: textS)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Supported formats: CSV, JSON, XLSX', style: TextStyle(fontSize: 11, color: textS)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () { Navigator.pop(ctx); _snack('Import feature coming soon'); },
                    child: const Text('Import', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }


  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor    = AppTheme.backgroundFill(brightness);

    return CustomScrollView(
      slivers: [
        // ── Sticky page header ──────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _ContentHeaderDelegate(
            brightness: brightness,
            bgColor: bgColor,
            onCreate: () {
              if (!AccessService.requireCreate(context, 'Content')) return;
              _showCreateForm();
            },
            onImport: _showImport,
          ),
        ),

        // ── Scrollable body ─────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content management card
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(brightness),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    border: Border.all(color: AppTheme.border(brightness)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── section header ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.list_alt_rounded, color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Text('Content Library',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(brightness))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLighter(brightness),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${_filtered.length}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                        ]),
                      ),
                      Divider(height: 1, color: AppTheme.border(brightness)),

                      // ── toolbar ───────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _ContentToolbar(
                          searchCtrl:      _searchCtrl,
                          onSearchChanged: (_) => setState(() {}),
                          typeFilter:      _typeFilter,
                          onTypeChanged:   (v) => setState(() => _typeFilter = v),
                          statusFilter:    _statusFilter,
                          onStatusChanged: (v) => setState(() => _statusFilter = v),
                          campaignFilter:  _campaignFilter,
                          campaigns:       _allCampaigns,
                          onCampaignChanged: (v) => setState(() => _campaignFilter = v),
                          sortBy:          _sortBy,
                          onSortChanged:   (v) => setState(() => _sortBy = v),
                        ),
                      ),

                      // ── table / cards ─────────────────────────────────
                      _filtered.isEmpty
                          ? _EmptyState(
                              icon: Icons.article_outlined,
                              message: 'No content found',
                              hint: 'Try adjusting your search or filters.',
                            )
                          : _ContentTable(
                              items: _filtered,
                              onView:      _showDetail,
                              onEdit:      _showEditForm,
                              onDuplicate: _duplicateItem,
                              onDelete:    _confirmDelete,
                            ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
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
class _ContentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Brightness brightness;
  final Color bgColor;
  final VoidCallback onCreate;
  final VoidCallback onImport;

  static const double _h = 80.0;

  const _ContentHeaderDelegate({
    required this.brightness,
    required this.bgColor,
    required this.onCreate,
    required this.onImport,
  });

  @override double get minExtent => _h;
  @override double get maxExtent => _h;

  @override
  bool shouldRebuild(_ContentHeaderDelegate old) =>
      old.brightness != brightness || old.bgColor != bgColor;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: bgColor,
      child: Container(
        height: _h,
        decoration: BoxDecoration(
          color: bgColor,
          border: overlapsContent
              ? Border(bottom: BorderSide(color: AppTheme.border(brightness), width: 1))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding, vertical: 12),
        child: _ContentPageHeader(onCreate: onCreate, onImport: onImport),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header bar — title + Import + Create Content
// ─────────────────────────────────────────────────────────────────────────────
class _ContentPageHeader extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onImport;
  const _ContentPageHeader({required this.onCreate, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (context, cst) {
      final narrow = cst.maxWidth < 540;

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
            child: const Icon(Icons.article_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Content',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Create, organize, schedule, and manage your marketing content.',
                    style: TextStyle(fontSize: 12, color: textSec),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
        ],
      );

      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
        if (!narrow) ...[
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_outlined, size: 14),
            label: const Text('Import'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary(brightness),
              side: BorderSide(color: AppTheme.border(brightness)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 15),
          label: Text(narrow ? 'Create' : '+ Create Content'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 12),
          actions,
        ],
      );
    });
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Stats Row — 4 compact KPI cards
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, published, scheduled, drafts;
  const _StatsRow({required this.total, required this.published, required this.scheduled, required this.drafts});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData('Total Content',  '$total',     Icons.article_outlined,         AppColors.primary,  '+${(total * 0.08).round()} this month'),
      _StatData('Published',      '$published', Icons.check_circle_outline,     AppColors.success,  'Live & active'),
      _StatData('Scheduled',      '$scheduled', Icons.schedule_rounded,         AppColors.info,     'Queued for publish'),
      _StatData('Drafts',         '$drafts',    Icons.edit_note_rounded,        AppColors.warning,  'In progress'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 700 ? 4 : c.maxWidth >= 420 ? 2 : 2;
      final w = (c.maxWidth - (cols - 1) * AppConstants.itemSpacing) / cols;
      return Wrap(
        spacing: AppConstants.itemSpacing,
        runSpacing: AppConstants.itemSpacing,
        children: cards.map((s) => SizedBox(width: w, child: _StatCard(data: s))).toList(),
      );
    });
  }
}

class _StatData {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color, this.sub);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Icon(data.icon, size: 18, color: data.color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(br))),
          const SizedBox(height: 1),
          Text(data.label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(br)), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(data.sub,
              style: TextStyle(fontSize: 10, color: data.color, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar — search + filters in one row (wraps on narrow)
// ─────────────────────────────────────────────────────────────────────────────
class _ContentToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final String typeFilter;
  final ValueChanged<String> onTypeChanged;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final String campaignFilter;
  final List<String> campaigns;
  final ValueChanged<String> onCampaignChanged;
  final String sortBy;
  final ValueChanged<String> onSortChanged;

  const _ContentToolbar({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.typeFilter,
    required this.onTypeChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.campaignFilter,
    required this.campaigns,
    required this.onCampaignChanged,
    required this.sortBy,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final br  = Theme.of(context).brightness;
    final fill = AppTheme.inputFill(br);
    final bord = AppTheme.border(br);
    final textP = AppTheme.textPrimary(br);
    final textS = AppTheme.textSecondary(br);

    final search = SizedBox(
      height: 38,
      child: TextField(
        controller: searchCtrl,
        onChanged: onSearchChanged,
        style: TextStyle(fontSize: 13, color: textP),
        decoration: InputDecoration(
          hintText: 'Search content…',
          hintStyle: TextStyle(fontSize: 13, color: textS),
          prefixIcon: Icon(Icons.search, size: 17, color: textS),
          filled: true,
          fillColor: fill,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: bord)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: bord)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    );

    final chips = Wrap(spacing: 8, runSpacing: 8, children: [
      _FChip(label: 'Type', value: typeFilter, items: _contentTypes, onChanged: onTypeChanged),
      _FChip(label: 'Status', value: statusFilter, items: _statusFilterLabels, onChanged: onStatusChanged),
      _FChip(label: 'Campaign', value: campaignFilter, items: campaigns, onChanged: onCampaignChanged),
      _FChip(label: 'Sort', value: sortBy, items: _sortOptions, onChanged: onSortChanged),
    ]);

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 680) {
        return Row(children: [
          SizedBox(width: 220, child: search),
          const SizedBox(width: 12),
          Expanded(child: chips),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        search,
        const SizedBox(height: 10),
        chips,
      ]);
    });
  }
}

class _FChip extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _FChip({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final br      = Theme.of(context).brightness;
    final isActive = value != 'All';
    final fill    = isActive ? AppColors.primaryLight.withValues(alpha: br == Brightness.dark ? 0.18 : 1.0) : AppTheme.inputFill(br);
    final bord    = isActive ? AppColors.primary.withValues(alpha: 0.4) : AppTheme.border(br);
    final fg      = isActive ? AppColors.primary : AppTheme.textPrimary(br);

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: AppTheme.surfaceColor(br),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), side: BorderSide(color: AppTheme.border(br))),
      itemBuilder: (_) => items.map((i) => PopupMenuItem(
        value: i,
        child: Text(i, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(br))),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppConstants.radiusMedium), border: Border.all(color: bord)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: $value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down, size: 16, color: fg),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Content Table — desktop table + mobile card fallback
// ─────────────────────────────────────────────────────────────────────────────
class _ContentTable extends StatelessWidget {
  final List<ContentItem> items;
  final ValueChanged<ContentItem> onView;
  final ValueChanged<ContentItem> onEdit;
  final ValueChanged<ContentItem> onDuplicate;
  final ValueChanged<ContentItem> onDelete;

  const _ContentTable({
    required this.items,
    required this.onView,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 760) {
        return _DesktopTable(items: items, onView: onView, onEdit: onEdit, onDuplicate: onDuplicate, onDelete: onDelete);
      }
      return _MobileCards(items: items, onView: onView, onEdit: onEdit, onDuplicate: onDuplicate, onDelete: onDelete);
    });
  }
}

// ── Desktop table ─────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final List<ContentItem> items;
  final ValueChanged<ContentItem> onView;
  final ValueChanged<ContentItem> onEdit;
  final ValueChanged<ContentItem> onDuplicate;
  final ValueChanged<ContentItem> onDelete;

  const _DesktopTable({required this.items, required this.onView, required this.onEdit, required this.onDuplicate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final br   = Theme.of(context).brightness;
    final bord = AppTheme.border(br);
    final hdr  = AppTheme.tableHeaderColor(br);
    final textS = AppTheme.textSecondary(br);

    return Column(children: [
      // table header
      Container(
        color: hdr,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(flex: 5, child: _TH('Content', textS)),
          Expanded(flex: 2, child: _TH('Type', textS)),
          Expanded(flex: 3, child: _TH('Campaign', textS)),
          Expanded(flex: 2, child: _TH('Status', textS)),
          Expanded(flex: 2, child: _TH('Author', textS)),
          Expanded(flex: 2, child: _TH('Updated', textS)),
          const SizedBox(width: 44, child: SizedBox.shrink()),
        ]),
      ),
      Divider(height: 1, color: bord),

      // rows
      ...items.asMap().entries.map((e) => _DesktopRow(
        item: e.value,
        isLast: e.key == items.length - 1,
        onView: onView,
        onEdit: onEdit,
        onDuplicate: onDuplicate,
        onDelete: onDelete,
      )),
    ]);
  }
}

class _DesktopRow extends StatefulWidget {
  final ContentItem item;
  final bool isLast;
  final ValueChanged<ContentItem> onView;
  final ValueChanged<ContentItem> onEdit;
  final ValueChanged<ContentItem> onDuplicate;
  final ValueChanged<ContentItem> onDelete;

  const _DesktopRow({required this.item, required this.isLast, required this.onView, required this.onEdit, required this.onDuplicate, required this.onDelete});

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final br       = Theme.of(context).brightness;
    final textP    = AppTheme.textPrimary(br);
    final textS    = AppTheme.textSecondary(br);
    final divColor = AppTheme.divider(br);
    final hoverBg  = AppTheme.tableRowHover(br);
    final item     = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        color: _hovered ? hoverBg : Colors.transparent,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // content col: icon + title + description
              Expanded(flex: 5, child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: item.typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(item.typeIcon, color: item.typeColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textP),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  if (item.description.isNotEmpty)
                    Text(item.description,
                        style: TextStyle(fontSize: 11, color: textS),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                ])),
              ])),
              // type
              Expanded(flex: 2, child: _TypeBadge(type: item.type)),
              // campaign
              Expanded(flex: 3, child: Text(item.campaignName,
                  style: TextStyle(fontSize: 12, color: textS), overflow: TextOverflow.ellipsis)),
              // status
              Expanded(flex: 2, child: StatusBadge(status: item.status)),
              // author
              Expanded(flex: 2, child: Text(item.creator,
                  style: TextStyle(fontSize: 12, color: textS), overflow: TextOverflow.ellipsis)),
              // updated
              Expanded(flex: 2, child: Text(_fmtDate(item.scheduledDate),
                  style: TextStyle(fontSize: 12, color: textS))),
              // action menu
              SizedBox(width: 44, child: _ActionMenu(item: item, onView: widget.onView, onEdit: widget.onEdit, onDuplicate: widget.onDuplicate, onDelete: widget.onDelete)),
            ]),
          ),
          if (!widget.isLast) Divider(height: 1, color: divColor),
        ]),
      ),
    );
  }
}

// ── Mobile cards ──────────────────────────────────────────────────────────────
class _MobileCards extends StatelessWidget {
  final List<ContentItem> items;
  final ValueChanged<ContentItem> onView;
  final ValueChanged<ContentItem> onEdit;
  final ValueChanged<ContentItem> onDuplicate;
  final ValueChanged<ContentItem> onDelete;

  const _MobileCards({required this.items, required this.onView, required this.onEdit, required this.onDuplicate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final br   = Theme.of(context).brightness;
    final div  = AppTheme.divider(br);

    return Column(children: items.asMap().entries.map((e) {
      final item   = e.value;
      final isLast = e.key == items.length - 1;
      final textP  = AppTheme.textPrimary(br);
      final textS  = AppTheme.textSecondary(br);

      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: item.typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: Icon(item.typeIcon, color: item.typeColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textP), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _TypeBadge(type: item.type),
                StatusBadge(status: item.status),
              ]),
              const SizedBox(height: 4),
              Text('${item.creator} · ${_fmtDate(item.scheduledDate)}', style: TextStyle(fontSize: 11, color: textS)),
              if (item.campaignName != '—')
                Text(item.campaignName, style: TextStyle(fontSize: 11, color: textS), overflow: TextOverflow.ellipsis),
            ])),
            _ActionMenu(item: item, onView: onView, onEdit: onEdit, onDuplicate: onDuplicate, onDelete: onDelete),
          ]),
        ),
        if (!isLast) Divider(height: 1, color: div),
      ]);
    }).toList());
  }
}

// ── Three-dot action menu ─────────────────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final ContentItem item;
  final ValueChanged<ContentItem> onView;
  final ValueChanged<ContentItem> onEdit;
  final ValueChanged<ContentItem> onDuplicate;
  final ValueChanged<ContentItem> onDelete;

  const _ActionMenu({required this.item, required this.onView, required this.onEdit, required this.onDuplicate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.iconColor(br)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), side: BorderSide(color: AppTheme.border(br))),
      color: AppTheme.surfaceColor(br),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'view':      onView(item);      break;
          case 'edit':      onEdit(item);      break;
          case 'duplicate': onDuplicate(item); break;
          case 'delete':    onDelete(item);    break;
        }
      },
      itemBuilder: (_) => [
        _menuItem('view',      Icons.visibility_outlined,   'View',      AppColors.primary),
        _menuItem('edit',      Icons.edit_outlined,         'Edit',      AppColors.info),
        _menuItem('duplicate', Icons.copy_outlined,         'Duplicate', AppColors.success),
        const PopupMenuDivider(),
        _menuItem('delete',    Icons.delete_outline_rounded,'Delete',    AppColors.danger),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Type badge
// ─────────────────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_typeIcon(type), size: 11, color: color),
        const SizedBox(width: 4),
        Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message, hint;
  const _EmptyState({required this.icon, required this.message, required this.hint});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Icon(icon, size: 44, color: AppTheme.textSecondary(br).withValues(alpha: 0.25)),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary(br))),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(br))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

// Table header cell
class _TH extends StatelessWidget {
  final String text;
  final Color color;
  const _TH(this.text, this.color);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color));
}

// Detail row in the view dialog
class _DRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color textSec, textPrimary;
  const _DRow({required this.icon, required this.label, required this.value, required this.textSec, required this.textPrimary});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 15, color: textSec),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: textSec))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// Form label
class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(br)));
  }
}

// Responsive two-col row (stacks below 420px)
class _RowOrCol extends StatelessWidget {
  final Widget left, right;
  const _RowOrCol({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth >= 400) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left), const SizedBox(width: 12), Expanded(child: right),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 14), right]);
    });
  }
}

// Dropdown field used in create/edit form
class _DField extends StatelessWidget {
  final String value;
  final List<String> items;
  final Brightness br;
  final ValueChanged<String> onChanged;
  const _DField({required this.value, required this.items, required this.br, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.inputFill(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceColor(br),
          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.iconColor(br)),
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(br)),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(br))))).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// Mini toolbar button inside content editor
class _MiniTb extends StatelessWidget {
  final String label;
  final Color textSec;
  const _MiniTb({required this.label, required this.textSec});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec)),
      ),
    );
  }
}

// Input decoration used in form fields
InputDecoration _dec(String hint, Brightness br) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(br)),
  filled: true,
  fillColor: AppTheme.inputFill(br),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: AppTheme.border(br))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: AppTheme.border(br))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
);

// Type color helper
Color _typeColor(String type) {
  switch (type) {
    case 'Blog Post':   return AppColors.primary;
    case 'Video':       return AppColors.danger;
    case 'Social Post': return AppColors.info;
    case 'Email':       return AppColors.warning;
    case 'Infographic': return AppColors.success;
    case 'Webinar':     return const Color(0xFFBB5CF8);
    default:            return AppColors.textSecondary;
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'Blog Post':   return Icons.article_outlined;
    case 'Video':       return Icons.play_circle_outline;
    case 'Social Post': return Icons.share_outlined;
    case 'Email':       return Icons.email_outlined;
    case 'Infographic': return Icons.bar_chart_outlined;
    case 'Webinar':     return Icons.videocam_outlined;
    default:            return Icons.insert_drive_file_outlined;
  }
}

// Date formatter
String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// Number formatter
String _fmtNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
