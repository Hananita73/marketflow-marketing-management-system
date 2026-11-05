// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../models/customer.dart';
import '../../models/notification_model.dart';
import '../../models/sms_campaign.dart';
import '../../services/access_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/badges/status_badge.dart';
import '../../widgets/common/custom_textfield.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CommunicationsScreen
//
// SMS Marketing module — create SMS campaigns, select recipients,
// preview message, schedule/send, and view history.
//
// Uses CustomScrollView + SliverPersistentHeader (same pattern as other screens).
// ─────────────────────────────────────────────────────────────────────────────

class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _searchQuery = '';
  String _statusFilter = 'All';

  List<SmsCampaign> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await SmsCampaignRepository.init();
    if (mounted) setState(() { _items = List.from(SmsCampaignRepository.getAll()); _loading = false; });
  }

  void _reload() => setState(() => _items = List.from(SmsCampaignRepository.getAll()));

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  // ── Filtering ──────────────────────────────────────────────────────────────
  List<SmsCampaign> get _filtered {
    final q = _searchQuery.toLowerCase();
    return _items.where((s) {
      final matchQ = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.message.toLowerCase().contains(q) ||
          (s.campaignId ?? '').toLowerCase().contains(q);
      final matchS = _statusFilter == 'All' || s.status == _statusFilter;
      return matchQ && matchS;
    }).toList();
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  int get _totalSent     => _items.fold(0, (s, x) => s + x.sentCount);
  int get _totalFailed   => _items.fold(0, (s, x) => s + x.failedCount);
  int get _totalRecipients => _items.fold(0, (s, x) => s + x.recipientCount);
  int get _scheduled     => _items.where((s) => s.status == 'Scheduled').length;

  // ── Snack ──────────────────────────────────────────────────────────────────
  void _snack(String msg, {Color color = AppColors.success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Create/Edit dialog ─────────────────────────────────────────────────────
  void _showDialog({SmsCampaign? existing}) {
    final isEdit  = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final msgCtrl  = TextEditingController(text: existing?.message ?? '');
    String campaignId = existing?.campaignId ?? '';
    String status = existing?.status ?? 'Draft';
    DateTime? scheduledAt = existing?.scheduledAt;
    List<int> selectedCustomerIds = existing?.recipients.map((r) => r.customerId).toList() ?? [];

    final campaigns = CampaignRepository.getAll()
        .where((c) => c.status == AppConstants.statusActive || c.status == AppConstants.statusApproved)
        .toList();
    final allCustomers = CustomerRepository.getAll();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final br       = Theme.of(ctx).brightness;
        final dialogBg = AppTheme.surfaceColor(br);
        final headerBg = br == Brightness.dark ? const Color(0xFF1E2A50) : const Color(0xFFEEF2FF);
        final textPri  = AppTheme.textPrimary(br);
        final textSec  = AppTheme.textSecondary(br);
        final fill     = AppTheme.inputFill(br);
        final border   = AppTheme.border(br);
        final dropBg   = AppTheme.surfaceColor(br);

        // Char count
        final charCount = msgCtrl.text.length;
        final smsCount  = (charCount / 160).ceil();

        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(color: AppTheme.border(br)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 680, maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.radiusLarge),
                    topRight: Radius.circular(AppConstants.radiusLarge),
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_rounded : Icons.sms_outlined,
                      color: AppColors.primary, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isEdit ? 'Edit SMS Campaign' : 'New SMS Campaign',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
                    Text('Create and schedule bulk SMS messages',
                        style: TextStyle(fontSize: 12, color: textSec)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: textSec, size: 20)),
                ]),
              ),

              // ── Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: fk,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Campaign name
                      CustomTextField(
                        controller: nameCtrl,
                        label: 'Campaign Name',
                        hint: 'e.g. Summer Promo SMS Blast',
                        prefixIcon: Icons.label_outline_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Link to marketing campaign
                      if (campaigns.isNotEmpty) ...[
                        Text('Link to Campaign (optional)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                            border: Border.all(color: border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: campaignId.isEmpty ? null : campaignId,
                              isExpanded: true, isDense: true,
                              hint: Text('Select campaign…',
                                  style: TextStyle(fontSize: 13, color: textSec)),
                              dropdownColor: dropBg,
                              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
                              style: TextStyle(fontSize: 13, color: textPri),
                              items: [
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('None', style: TextStyle(fontSize: 13, color: textSec)),
                                ),
                                ...campaigns.map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.name} (${c.id})',
                                      style: TextStyle(fontSize: 13, color: textPri),
                                      overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: (v) => setLocal(() => campaignId = v ?? ''),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // SMS message
                      Text('Message',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: msgCtrl,
                        maxLines: 5,
                        maxLength: 1600,
                        style: TextStyle(fontSize: 13, color: textPri),
                        onChanged: (_) => setLocal(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Message is required';
                          if (v.trim().length < 5) return 'Message too short';
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Type your SMS message here…',
                          hintStyle: TextStyle(fontSize: 13, color: textSec),
                          filled: true, fillColor: fill,
                          counterText: '',
                          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('$charCount characters · $smsCount SMS part${smsCount != 1 ? "s" : ""}',
                            style: TextStyle(fontSize: 11, color: textSec)),
                        const Spacer(),
                        if (charCount > 1440)
                          Text('Approaching limit', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                      ]),
                      const SizedBox(height: 14),

                      // Status
                      _FormDrop(
                        label: 'Status',
                        value: status,
                        items: const ['Draft', 'Scheduled', 'Sent', 'Cancelled'],
                        fill: fill, border: border, dropBg: dropBg,
                        textPri: textPri, textSec: textSec,
                        onChanged: (v) => setLocal(() => status = v),
                      ),
                      const SizedBox(height: 14),

                      // Schedule date/time
                      if (status == 'Scheduled') ...[
                        Text('Scheduled Date & Time',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: scheduledAt ?? DateTime.now().add(const Duration(hours: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d == null) return;
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(
                                  scheduledAt ?? DateTime.now()),
                            );
                            if (t == null) return;
                            setLocal(() => scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                          },
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              border: Border.all(color: border),
                            ),
                            child: Row(children: [
                              Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                scheduledAt == null
                                    ? 'Select date and time…'
                                    : '${scheduledAt!.day}/${scheduledAt!.month}/${scheduledAt!.year}  ${scheduledAt!.hour.toString().padLeft(2,'0')}:${scheduledAt!.minute.toString().padLeft(2,'0')}',
                                style: TextStyle(fontSize: 13,
                                    color: scheduledAt == null ? textSec : textPri),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Recipients selection
                      Row(children: [
                        Text('Recipients',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setLocal(() {
                            if (selectedCustomerIds.length == allCustomers.length) {
                              selectedCustomerIds = [];
                            } else {
                              selectedCustomerIds = allCustomers.map((c) => c.id).toList();
                            }
                          }),
                          icon: Icon(
                            selectedCustomerIds.length == allCustomers.length
                                ? Icons.deselect : Icons.select_all,
                            size: 14,
                          ),
                          label: Text(
                            selectedCustomerIds.length == allCustomers.length
                                ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: border),
                        ),
                        child: allCustomers.isEmpty
                            ? Center(child: Text('No customers found',
                                style: TextStyle(color: textSec, fontSize: 13)))
                            : ListView.builder(
                                itemCount: allCustomers.length,
                                itemBuilder: (_, i) {
                                  final c = allCustomers[i];
                                  final selected = selectedCustomerIds.contains(c.id);
                                  final hasPhone = c.phone.isNotEmpty;
                                  return CheckboxListTile(
                                    value: selected,
                                    dense: true,
                                    activeColor: AppColors.primary,
                                    onChanged: hasPhone
                                        ? (v) => setLocal(() {
                                              if (v == true) {
                                                selectedCustomerIds.add(c.id);
                                              } else {
                                                selectedCustomerIds.remove(c.id);
                                              }
                                            })
                                        : null,
                                    title: Text(c.name,
                                        style: TextStyle(fontSize: 13, color: hasPhone ? textPri : textSec)),
                                    subtitle: Text(
                                      hasPhone ? c.phone : 'No phone number',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: hasPhone ? textSec : AppColors.warning,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text('${selectedCustomerIds.length} recipient${selectedCustomerIds.length != 1 ? "s" : ""} selected',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ),

              // ── Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(br),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppConstants.radiusLarge),
                    bottomRight: Radius.circular(AppConstants.radiusLarge),
                  ),
                  border: Border(top: BorderSide(color: AppTheme.divider(br))),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!fk.currentState!.validate()) return;
                      if (!AccessService.requireSave(context, isEdit, 'Communications')) return;
                      if (selectedCustomerIds.isEmpty) {
                        _snack('Please select at least one recipient.', color: AppColors.warning);
                        return;
                      }

                      // Build recipients list with phone validation
                      final recipients = selectedCustomerIds
                          .map((id) => CustomerRepository.findById(id))
                          .whereType<Customer>()
                          .where((c) => c.phone.isNotEmpty)
                          .map((c) => SmsRecipient(
                                customerId: c.id,
                                name: c.name,
                                phone: c.phone,
                                deliveryStatus: 'pending',
                              ))
                          .toList();

                      // When editing, existing is guaranteed non-null.
                      final ex = existing;
                      final sms = SmsCampaign(
                        id: isEdit ? ex!.id : SmsCampaignRepository.nextId(),
                        name: nameCtrl.text.trim(),
                        campaignId: campaignId.isEmpty ? null : campaignId,
                        message: msgCtrl.text.trim(),
                        status: status,
                        recipientCount: recipients.length,
                        sentCount: isEdit ? ex!.sentCount : 0,
                        failedCount: isEdit ? ex!.failedCount : 0,
                        scheduledAt: scheduledAt,
                        sentAt: isEdit ? ex!.sentAt : null,
                        createdBy: AuthService().currentName,
                        providerRef: '',
                        recipients: recipients,
                        createdAt: isEdit ? ex!.createdAt : DateTime.now(),
                      );

                      setState(() {
                        isEdit
                            ? SmsCampaignRepository.update(sms)
                            : SmsCampaignRepository.add(sms);
                        _reload();
                      });

                      AuditLogService.log(
                        action: isEdit ? 'update' : 'create',
                        module: 'SMS',
                        recordId: sms.id,
                        recordName: sms.name,
                        details: {'recipients': recipients.length, 'status': sms.status},
                      );

                      Navigator.pop(ctx);
                      _snack(isEdit ? 'SMS campaign updated' : 'SMS campaign created');
                    },
                    icon: Icon(isEdit ? Icons.save_outlined : Icons.add_rounded, size: 16),
                    label: Text(isEdit ? 'Save Changes' : 'Create Campaign'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── Preview dialog ─────────────────────────────────────────────────────────
  void _showPreview(SmsCampaign sms) {
    showDialog(
      context: context,
      builder: (ctx) {
        final br       = Theme.of(ctx).brightness;
        final dialogBg = AppTheme.surfaceColor(br);
        final textPri  = AppTheme.textPrimary(br);
        final textSec  = AppTheme.textSecondary(br);

        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(color: AppTheme.border(br)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.preview_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text('SMS Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: textSec, size: 20)),
                ]),
                const SizedBox(height: 16),
                // Phone mockup
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 16,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.sms, color: Colors.white, size: 14)),
                      const SizedBox(width: 8),
                      Text('MarketFlow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(br),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(sms.message,
                          style: TextStyle(fontSize: 13, color: textPri, height: 1.5)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                _PreviewRow(icon: Icons.people_outline, label: 'Recipients', value: '${sms.recipientCount}', textPri: textPri, textSec: textSec),
                const SizedBox(height: 8),
                _PreviewRow(icon: Icons.text_snippet_outlined, label: 'Characters', value: '${sms.message.length} (${(sms.message.length / 160).ceil()} part${(sms.message.length / 160).ceil() != 1 ? "s" : ""})', textPri: textPri, textSec: textSec),
                if (sms.scheduledAt != null) ...[
                  const SizedBox(height: 8),
                  _PreviewRow(icon: Icons.schedule_outlined, label: 'Scheduled', value: '${sms.scheduledAt!.day}/${sms.scheduledAt!.month}/${sms.scheduledAt!.year}  ${sms.scheduledAt!.hour.toString().padLeft(2,'0')}:${sms.scheduledAt!.minute.toString().padLeft(2,'0')}', textPri: textPri, textSec: textSec),
                ],
                const SizedBox(height: 20),
                // Warning when no gateway configured
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'SMS delivery requires a configured gateway (e.g. Twilio, Africa\'s Talking). '
                      'Configure credentials in Settings → Integrations.',
                      style: TextStyle(fontSize: 11, color: AppColors.warning, height: 1.4),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _simulateSend(sms);
                    },
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Send Now'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── Simulate send (no real gateway configured) ─────────────────────────────
  void _simulateSend(SmsCampaign sms) {
    if (!AccessService.canEdit('Communications')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your role does not have permission to send SMS campaigns.'),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // In production this would call the configured SMS gateway API.
    // Here we update the status to 'Sent' and record results.
    final updated = sms.copyWith(
      status: 'Sent',
      sentCount: sms.recipientCount,
      failedCount: 0,
      sentAt: DateTime.now(),
      providerRef: 'SIM_${DateTime.now().millisecondsSinceEpoch}',
    );
    setState(() {
      SmsCampaignRepository.update(updated);
      _reload();
    });
    AuditLogService.log(
      action: 'create', module: 'SMS',
      recordId: sms.id, recordName: '${sms.name} — sent',
      details: {'recipients': sms.recipientCount, 'status': 'Sent'},
    );
    NotificationRepository.add(
      title: 'SMS Campaign Sent',
      message: '"${sms.name}" sent to ${sms.recipientCount} recipients.',
      category: NotificationCategory.system,
    );
    _snack('"${sms.name}" marked as Sent. ${sms.recipientCount} recipients. '
        '(Configure an SMS gateway in Settings for real delivery.)');
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────
  void _confirmDelete(SmsCampaign sms) {
    showDialog(context: context, builder: (ctx) {
      final br = Theme.of(ctx).brightness;
      return AlertDialog(
        backgroundColor: AppTheme.surfaceColor(br),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          side: BorderSide(color: AppTheme.border(br)),
        ),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
          const SizedBox(width: 8),
          Text('Delete Campaign?', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Text('Remove "${sms.name}"? This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!AccessService.requireDelete(context, 'Communications')) return;
              setState(() { SmsCampaignRepository.remove(sms.id); _reload(); });
              AuditLogService.logDelete('SMS', sms.id, sms.name);
              Navigator.pop(ctx);
              _snack('Campaign deleted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      );
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;

    return CustomScrollView(
      slivers: [
        // ── Sticky header
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            brightness: br,
            bgColor: AppTheme.backgroundFill(br),
            child: _PageHeaderBar(onNew: () {
              if (!AccessService.requireCreate(context, 'Communications')) return;
              _showDialog();
            }),
          ),
        ),
        // ── Body
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(color: AppColors.primary)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Stats
                    _StatsRow(
                      totalSent: _totalSent,
                      totalFailed: _totalFailed,
                      totalRecipients: _totalRecipients,
                      scheduled: _scheduled,
                    ),
                    const SizedBox(height: AppConstants.sectionSpacing),

                    // Filter row + tabs
                    _FilterBar(
                      searchQuery: _searchQuery,
                      statusFilter: _statusFilter,
                      onSearchChanged: (v) => setState(() => _searchQuery = v),
                      onStatusChanged: (v) => setState(() => _statusFilter = v),
                    ),
                    const SizedBox(height: 16),

                    // Campaign list
                    if (_filtered.isEmpty)
                      _EmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, i2) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _SmsCampaignCard(
                          sms: _filtered[i],
                          onEdit: () => _showDialog(existing: _filtered[i]),
                          onPreview: () => _showPreview(_filtered[i]),
                          onDelete: () => _confirmDelete(_filtered[i]),
                          onSend: () => _simulateSend(_filtered[i]),
                        ),
                      ),
                    const SizedBox(height: AppConstants.sectionSpacing),
                  ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview row helper
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color textPri, textSec;
  const _PreviewRow({required this.icon, required this.label, required this.value,
      required this.textPri, required this.textSec});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: textSec),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: textPri))),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky header
// ─────────────────────────────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Brightness brightness;
  final Color bgColor;
  static const double _h = 80.0;
  const _StickyHeaderDelegate({required this.child, required this.brightness, required this.bgColor});

  @override double get minExtent => _h;
  @override double get maxExtent => _h;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) =>
      Material(
        elevation: overlapsContent ? 2 : 0,
        color: bgColor,
        child: Container(
          height: _h,
          decoration: BoxDecoration(
            color: bgColor,
            border: overlapsContent ? Border(bottom: BorderSide(color: AppTheme.border(brightness))) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding, vertical: 12),
          child: child,
        ),
      );

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.brightness != brightness || old.bgColor != bgColor || old.child != child;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header bar
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeaderBar extends StatelessWidget {
  final VoidCallback onNew;
  const _PageHeaderBar({required this.onNew});

  @override
  Widget build(BuildContext context) {
    final br     = Theme.of(context).brightness;
    final textSec = AppTheme.textSecondary(br);

    return LayoutBuilder(builder: (_, cst) {
      final narrow = cst.maxWidth < 600;
      final titleBlock = Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: const Icon(Icons.sms_outlined, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Communications', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('SMS campaigns, scheduling and delivery tracking.',
              style: TextStyle(color: textSec, fontSize: 12)),
        ]),
      ]);

      final actions = ElevatedButton.icon(
        onPressed: onNew,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('New SMS Campaign'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      );

      if (narrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          titleBlock, const SizedBox(height: 8), actions,
        ]);
      }
      return Row(children: [titleBlock, const Spacer(), actions]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalSent, totalFailed, totalRecipients, scheduled;
  const _StatsRow({required this.totalSent, required this.totalFailed,
      required this.totalRecipients, required this.scheduled});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, cst) {
      final w = (cst.maxWidth - 3 * AppConstants.itemSpacing) / 4;
      return Wrap(spacing: AppConstants.itemSpacing, runSpacing: AppConstants.itemSpacing, children: [
        SizedBox(width: w, child: _StatCard(title: 'Total Recipients', value: '$totalRecipients', icon: Icons.people_outline, color: AppColors.primary)),
        SizedBox(width: w, child: _StatCard(title: 'Messages Sent',    value: '$totalSent',       icon: Icons.send_outlined,   color: AppColors.success)),
        SizedBox(width: w, child: _StatCard(title: 'Failed',           value: '$totalFailed',     icon: Icons.error_outline,   color: AppColors.danger)),
        SizedBox(width: w, child: _StatCard(title: 'Scheduled',        value: '$scheduled',       icon: Icons.schedule_outlined, color: AppColors.warning)),
      ]);
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(title, style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppConstants.radiusMedium)), child: Icon(icon, size: 18, color: color)),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(color: AppTheme.textPrimary(br), fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String searchQuery, statusFilter;
  final ValueChanged<String> onSearchChanged, onStatusChanged;
  const _FilterBar({required this.searchQuery, required this.statusFilter,
      required this.onSearchChanged, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final br     = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final fill   = AppTheme.inputFill(br);
    final border = AppTheme.border(br);

    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 38,
          child: TextField(
            onChanged: onSearchChanged,
            style: TextStyle(fontSize: 13, color: textPri),
            decoration: InputDecoration(
              hintText: 'Search campaigns…', hintStyle: TextStyle(fontSize: 13, color: textSec),
              prefixIcon: Icon(Icons.search, size: 18, color: textSec),
              filled: true, fillColor: fill, contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppConstants.radiusMedium), border: Border.all(color: border)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: statusFilter, isDense: true,
            dropdownColor: AppTheme.surfaceColor(br),
            icon: Icon(Icons.toggle_on_outlined, size: 16, color: AppColors.primary),
            style: TextStyle(fontSize: 12, color: textPri),
            items: ['All', 'Draft', 'Scheduled', 'Sent', 'Failed', 'Cancelled']
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, color: textPri))))
                .toList(),
            onChanged: (v) => onStatusChanged(v!),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMS Campaign card
// ─────────────────────────────────────────────────────────────────────────────

class _SmsCampaignCard extends StatelessWidget {
  final SmsCampaign sms;
  final VoidCallback onEdit, onPreview, onDelete, onSend;
  const _SmsCampaignCard({required this.sms, required this.onEdit,
      required this.onPreview, required this.onDelete, required this.onSend});

  Color _statusColor(String s) {
    switch (s) {
      case 'Sent':      return AppColors.success;
      case 'Scheduled': return AppColors.info;
      case 'Failed':    return AppColors.danger;
      case 'Draft':     return AppColors.warning;
      default:          return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Sent':      return Icons.check_circle_outline;
      case 'Scheduled': return Icons.schedule_outlined;
      case 'Failed':    return Icons.error_outline;
      case 'Draft':     return Icons.edit_note_outlined;
      default:          return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final br       = Theme.of(context).brightness;
    final cardBg   = AppTheme.cardColor(br);
    final borderCol = AppTheme.border(br);
    final textPri  = AppTheme.textPrimary(br);
    final textSec  = AppTheme.textSecondary(br);
    final sc       = _statusColor(sms.status);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(children: [
        // coloured top strip
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: sc,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppConstants.radiusLarge),
              topRight: Radius.circular(AppConstants.radiusLarge),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title row
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Icon(_statusIcon(sms.status), color: sc, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sms.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPri)),
                if (sms.campaignId != null && sms.campaignId!.isNotEmpty)
                  Text('Campaign: ${sms.campaignId}',
                      style: TextStyle(fontSize: 11, color: textSec)),
              ])),
              StatusBadge(status: sms.status),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: textSec, size: 20),
                color: AppTheme.surfaceColor(br),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  side: BorderSide(color: borderCol),
                ),
                onSelected: (v) {
                  if (v == 'edit')    onEdit();
                  if (v == 'preview') onPreview();
                  if (v == 'send')    onSend();
                  if (v == 'delete')  onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'preview', child: Row(children: [
                    const Icon(Icons.preview_outlined, size: 16, color: AppColors.info),
                    const SizedBox(width: 8), const Text('Preview & Send'),
                  ])),
                  if (sms.status == 'Draft' || sms.status == 'Scheduled') ...[
                    PopupMenuItem(value: 'send', child: Row(children: [
                      const Icon(Icons.send_outlined, size: 16, color: AppColors.success),
                      const SizedBox(width: 8), const Text('Send Now'),
                    ])),
                    PopupMenuItem(value: 'edit', child: Row(children: [
                      const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8), const Text('Edit'),
                    ])),
                  ],
                  PopupMenuItem(value: 'delete', child: Row(children: [
                    const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                    const SizedBox(width: 8), const Text('Delete', style: TextStyle(color: AppColors.danger)),
                  ])),
                ],
              ),
            ]),
            const SizedBox(height: 12),

            // Message preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(br),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Text(
                sms.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: textPri, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(children: [
              _InfoChip(icon: Icons.people_outline, label: '${sms.recipientCount} recipients',
                  color: AppColors.primary, br: br),
              const SizedBox(width: 8),
              if (sms.sentCount > 0)
                _InfoChip(icon: Icons.check_circle_outline, label: '${sms.sentCount} sent',
                    color: AppColors.success, br: br),
              if (sms.failedCount > 0) ...[
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.error_outline, label: '${sms.failedCount} failed',
                    color: AppColors.danger, br: br),
              ],
              const Spacer(),
              if (sms.scheduledAt != null)
                Text(
                  '${sms.scheduledAt!.day}/${sms.scheduledAt!.month}/${sms.scheduledAt!.year}',
                  style: TextStyle(fontSize: 11, color: textSec),
                )
              else
                Text(
                  '${sms.createdAt.day}/${sms.createdAt.month}/${sms.createdAt.year}',
                  style: TextStyle(fontSize: 11, color: textSec),
                ),
            ]),

            // Delivery rate bar (only when sent)
            if (sms.sentCount > 0 && sms.recipientCount > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sms.deliveryRate,
                      backgroundColor: AppColors.success.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(sms.deliveryRate * 100).toStringAsFixed(0)}% delivered',
                  style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Brightness br;
  const _InfoChip({required this.icon, required this.label, required this.color, required this.br});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Center(child: Column(children: [
        Icon(Icons.sms_outlined, size: 52,
            color: AppTheme.textSecondary(br).withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text('No SMS campaigns yet',
            style: TextStyle(color: AppTheme.textPrimary(br), fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Create your first SMS campaign to reach customers directly.',
            style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 13)),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable form dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _FormDrop extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final Color fill, border, dropBg, textPri, textSec;
  final ValueChanged<String> onChanged;

  const _FormDrop({required this.label, required this.value, required this.items,
      required this.fill, required this.border, required this.dropBg,
      required this.textPri, required this.textSec, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value, isDense: true, isExpanded: true,
              dropdownColor: dropBg,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
              style: TextStyle(fontSize: 13, color: textPri),
              items: items.map((i) => DropdownMenuItem(
                value: i, child: Text(i, style: TextStyle(fontSize: 13, color: textPri)),
              )).toList(),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ]);
}
