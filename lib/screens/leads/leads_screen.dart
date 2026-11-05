// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../models/lead.dart';
import '../../models/notification_model.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../widgets/common/custom_textfield.dart';
import '../../widgets/charts/lead_funnel_chart.dart';
import '../../widgets/charts/lead_sources_chart.dart';
import '../../widgets/badges/status_badge.dart';
import '../../utils/input_validators.dart';

// -----------------------------------------------------------------------------
// LeadsScreen � selfScrolling: true in routes.dart
// -----------------------------------------------------------------------------

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterSource = 'All';
  String _filterStatus = 'All';
  String _sortBy       = 'Newest';
  int    _currentPage  = 1;

  List<Lead> get _filtered {
    var list = LeadRepository.getAll().toList();
    final q  = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((l) =>
          l.name.toLowerCase().contains(q) ||
          l.company.toLowerCase().contains(q) ||
          l.email.toLowerCase().contains(q)).toList();
    }
    if (_filterSource != 'All') list = list.where((l) => l.source == _filterSource).toList();
    if (_filterStatus != 'All') list = list.where((l) => l.status == _filterStatus).toList();
    switch (_sortBy) {
      case 'Score High': list = List.from(list)..sort((a, b) => b.score.compareTo(a.score)); break;
      case 'Score Low':  list = List.from(list)..sort((a, b) => a.score.compareTo(b.score)); break;
      case 'Oldest':     list = List.from(list)..sort((a, b) => a.createdAt.compareTo(b.createdAt)); break;
      default:           list = List.from(list)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  int get _totalPages => (_filtered.length / AppConstants.defaultPageSize).ceil().clamp(1, 999);
  List<Lead> get _pageItems {
    final start = (_currentPage - 1) * AppConstants.defaultPageSize;
    final end   = (start + AppConstants.defaultPageSize).clamp(0, _filtered.length);
    if (start >= _filtered.length) return [];
    return _filtered.sublist(start, end);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -- snack -----------------------------------------------------------------
  void _snack(String msg, {Color color = AppColors.success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // -- Add / Edit Lead dialog -------------------------------------------------
  void _showDialog({Lead? existing}) {
    final isEdit      = existing != null;
    final nameCtrl    = TextEditingController(text: existing?.name    ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final emailCtrl   = TextEditingController(text: existing?.email   ?? '');
    final phoneCtrl   = TextEditingController(text: existing?.phone   ?? '');
    String source   = existing?.source   ?? 'Website';
    String status   = existing?.status   ?? AppConstants.leadNew;
    String priority = existing?.priority ?? 'Medium';
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final br       = Theme.of(ctx).brightness;
        final dialogBg = AppTheme.surfaceColor(br);
        final headerBg = br == Brightness.dark ? const Color(0xFF2A2650) : AppColors.primaryLight;
        final textPri  = AppTheme.textPrimary(br);
        final textSec  = AppTheme.textSecondary(br);
        final fill     = AppTheme.inputFill(br);
        final border   = AppTheme.border(br);
        final dropBg   = AppTheme.surfaceColor(br);

        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(color: AppTheme.border(br)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // header
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
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(isEdit ? 'Edit Lead' : 'New Lead',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: textSec, size: 20),
                  ),
                ]),
              ),
              // body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: fk,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CustomTextField(controller: nameCtrl, label: 'Full Name',
                          hint: 'e.g. Abebe Kebede',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: 14),
                      CustomTextField(controller: companyCtrl, label: 'Company',
                          hint: 'e.g. TechWave Inc.',
                          prefixIcon: Icons.business_outlined,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (_, cst) {
                        final two = cst.maxWidth > 400;
                        return Flex(direction: two ? Axis.horizontal : Axis.vertical, children: [
                          Flexible(flex: two ? 1 : 0, child: CustomTextField(
                              controller: emailCtrl, label: 'Email',
                              hint: 'name@company.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: InputValidators.email)),
                          SizedBox(width: two ? 12 : 0, height: two ? 0 : 12),
                          Flexible(flex: two ? 1 : 0, child: CustomTextField(
                              controller: phoneCtrl, label: 'Phone',
                              hint: '+251 9XX XXX XXX',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: InputValidators.ethiopianPhone)),
                        ]);
                      }),
                      const SizedBox(height: 14),
                      LayoutBuilder(builder: (_, cst) {
                        final two = cst.maxWidth > 400;
                        return Flex(direction: two ? Axis.horizontal : Axis.vertical, children: [
                          Flexible(flex: two ? 1 : 0, child: _DlgDrop(
                              label: 'Source', value: source,
                              items: const ['Website','Social Media','Email','Referrals','Paid Ads','Others'],
                              fillColor: fill, borderColor: border, dropColor: dropBg,
                              textColor: textPri, secColor: textSec,
                              onChanged: (v) => setLocal(() => source = v))),
                          SizedBox(width: two ? 12 : 0, height: two ? 0 : 12),
                          Flexible(flex: two ? 1 : 0, child: _DlgDrop(
                              label: 'Status', value: status,
                              items: [AppConstants.leadNew, AppConstants.leadContacted,
                                      AppConstants.leadQualified, AppConstants.leadUnqualified,
                                      AppConstants.leadConverted],
                              fillColor: fill, borderColor: border, dropColor: dropBg,
                              textColor: textPri, secColor: textSec,
                              onChanged: (v) => setLocal(() => status = v))),
                        ]);
                      }),
                      const SizedBox(height: 14),
                      _DlgDrop(label: 'Priority', value: priority,
                          items: const ['High','Medium','Low'],
                          fillColor: fill, borderColor: border, dropColor: dropBg,
                          textColor: textPri, secColor: textSec,
                          onChanged: (v) => setLocal(() => priority = v)),
                    ]),
                  ),
                ),
              ),
              // footer
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
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (!fk.currentState!.validate()) return;
                      if (!AccessService.requireSave(context, isEdit, 'Leads')) return;
                      final updated = Lead(
                        id: isEdit ? existing.id : LeadRepository.nextId(),
                        name: nameCtrl.text.trim(),
                        company: companyCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        source: source,
                        score: isEdit ? existing.score : 50,
                        assignedTo: isEdit ? existing.assignedTo : AuthService().currentName,
                        status: status,
                        priority: priority,
                        createdAt: isEdit ? existing.createdAt : DateTime.now(),
                      );
                      setState(() {
                        isEdit ? LeadRepository.update(updated) : LeadRepository.add(updated);
                      });
                      AuditLogService.log(
                        action: isEdit ? 'update' : 'create',
                        module: 'Leads',
                        recordId: updated.id.toString(),
                        recordName: updated.name,
                      );
                      Navigator.pop(ctx);
                      _snack(isEdit ? 'Lead updated' : 'Lead added');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEdit ? 'Save Changes' : 'Add Lead'),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // -- Convert Lead dialog ---------------------------------------------------
  void _showConvertDialog(Lead lead) {
    // Only qualified leads can be converted.
    if (lead.status == AppConstants.leadConverted) {
      _snack('This lead has already been converted.', color: AppColors.warning);
      return;
    }
    if (lead.status != AppConstants.leadQualified) {
      _snack('Only Qualified leads can be converted. Please update the lead status first.',
          color: AppColors.warning);
      return;
    }

    final valueCtrl   = TextEditingController(text: '10000');
    final custNameCtrl  = TextEditingController(text: lead.name);
    final custEmailCtrl = TextEditingController(text: lead.email);
    String oppStage     = 'New';
    String custSegment  = 'Retail';
    bool createCustomer = true;
    String campaignId   = '';
    bool saving         = false;

    final campaigns = CampaignRepository.getAll()
        .where((c) => c.status == AppConstants.statusActive ||
                      c.status == AppConstants.statusApproved)
        .toList();
    if (campaigns.isNotEmpty) campaignId = campaigns.first.id;

    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final br       = Theme.of(ctx).brightness;
        final dialogBg = AppTheme.surfaceColor(br);
        final headerBg = br == Brightness.dark ? const Color(0xFF1A2650) : const Color(0xFFEEF2FF);
        final textPri  = AppTheme.textPrimary(br);
        final textSec  = AppTheme.textSecondary(br);
        final fill     = AppTheme.inputFill(br);
        final border   = AppTheme.border(br);
        final dropBg   = AppTheme.surfaceColor(br);

        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(color: AppTheme.border(br)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // -- Header
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
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Convert Lead', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: textPri,
                    )),
                    Text('Create an Opportunity ${createCustomer ? "& Customer" : ""} from this lead',
                        style: TextStyle(fontSize: 12, color: textSec)),
                  ])),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: textSec, size: 20),
                  ),
                ]),
              ),

              // -- Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: fk,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Lead summary chip
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              lead.name.split(' ').take(2).map((w) => w[0].toUpperCase()).join(),
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lead.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPri)),
                            Text('${lead.company}  �  Score: ${lead.score}  �  ${lead.source}',
                                style: TextStyle(fontSize: 11, color: textSec)),
                          ])),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // -- Section: Opportunity
                      _SectionTitle('Opportunity Details', Icons.business_center_outlined, textPri),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: valueCtrl,
                        label: 'Opportunity Value (ETB)',
                        hint: '10000',
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null) return 'Must be a number';
                          if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _DlgDrop(
                        label: 'Initial Stage',
                        value: oppStage,
                        items: const ['New', 'Qualified', 'Proposal', 'Negotiation'],
                        fillColor: fill, borderColor: border, dropColor: dropBg,
                        textColor: textPri, secColor: textSec,
                        onChanged: (v) => setLocal(() => oppStage = v),
                      ),
                      const SizedBox(height: 12),

                      // Campaign association
                      if (campaigns.isNotEmpty) ...[
                        Text('Associate Campaign',
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
                              value: campaignId.isEmpty ? campaigns.first.id : campaignId,
                              isExpanded: true, isDense: true,
                              dropdownColor: dropBg,
                              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
                              style: TextStyle(fontSize: 13, color: textPri),
                              items: campaigns.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.name} (${c.id})',
                                    style: TextStyle(fontSize: 13, color: textPri),
                                    overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) => setLocal(() => campaignId = v ?? ''),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // -- Section: Customer
                      Row(children: [
                        Expanded(child: _SectionTitle('Create Customer', Icons.person_add_outlined, textPri)),
                        Switch(
                          value: createCustomer,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => setLocal(() => createCustomer = v),
                        ),
                      ]),

                      if (createCustomer) ...[
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: custNameCtrl,
                          label: 'Customer Name',
                          hint: lead.name,
                          prefixIcon: Icons.person_outline_rounded,
                          validator: createCustomer
                              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
                              : null,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: custEmailCtrl,
                          label: 'Customer Email',
                          hint: lead.email,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: createCustomer
                              ? (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!v.contains('@')) return 'Invalid email';
                                  return null;
                                }
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _DlgDrop(
                          label: 'Customer Segment',
                          value: custSegment,
                          items: const ['VIP', 'Corporate', 'Retail', 'SME', 'Technology'],
                          fillColor: fill, borderColor: border, dropColor: dropBg,
                          textColor: textPri, secColor: textSec,
                          onChanged: (v) => setLocal(() => custSegment = v),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),

              // -- Footer
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
                  OutlinedButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () {
                            if (!fk.currentState!.validate()) return;
                            setLocal(() => saving = true);
                            try {
                              final result = LeadRepository.convertToOpportunityAndCustomer(
                                lead: lead,
                                campaignId: campaignId,
                                opportunityValue: double.parse(valueCtrl.text.trim()),
                                opportunityStage: oppStage,
                                convertToCustomer: createCustomer,
                                customerName: custNameCtrl.text.trim(),
                                customerEmail: custEmailCtrl.text.trim(),
                                customerSegment: custSegment,
                                assignedStaff: AuthService().currentName,
                              );
                              // Audit
                              AuditLogService.logConvert(
                                'Leads',
                                lead.id.toString(),
                                lead.name,
                                details: {
                                  'opportunityId': result['opportunityId'],
                                  'customerId': result['customerId'],
                                },
                              );
                              // Notify
                              NotificationRepository.add(
                                title: 'Lead Converted',
                                message:
                                    '${lead.name} converted to Opportunity${createCustomer ? " & Customer" : ""}.',
                                category: NotificationCategory.lead,
                              );
                              setState(() {});
                              Navigator.pop(ctx);
                              _snack(
                                  'Lead converted successfully! Opportunity${createCustomer ? " & Customer" : ""} created.');
                            } catch (e) {
                              setLocal(() => saving = false);
                              _snack('Conversion failed: $e', color: AppColors.danger);
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Convert Lead'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // -- Delete confirm --------------------------------------------------------
  void _confirmDelete(Lead l) {
    showDialog(
      context: context,
      builder: (ctx) {
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
            Text('Delete Lead?',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          content: Text('Remove "${l.name}"? This cannot be undone.',
              style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!AccessService.requireDelete(context, 'Leads')) return;
                setState(() => LeadRepository.remove(l.id));
                AuditLogService.logDelete('Leads', l.id.toString(), l.name);
                Navigator.pop(ctx);
                _snack('Lead removed');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // -- Permission helpers ----------------------------------------------------
  bool _canCreateLeads() => AccessService.canCreate('Leads');
  bool _canConvert()     => AccessService.canEdit('Leads');

  // -- Build -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final all        = LeadRepository.getAll();
    final canCreate  = _canCreateLeads();
    final canConvert = _canConvert();

    final total      = all.length;
    final qualified  = all.where((l) => l.status == AppConstants.leadQualified).length;
    final newCount   = all.where((l) => l.status == AppConstants.leadNew).length;
    final conversion = total > 0
        ? ((all.where((l) => l.status == AppConstants.leadConverted).length / total) * 100).toInt()
        : 0;

    return CustomScrollView(
      slivers: [
        // -- Sticky header
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            brightness: brightness,
            bgColor: AppTheme.backgroundFill(brightness),
            child: _PageHeaderBar(canCreate: canCreate, onNewTap: () => _showDialog()),
          ),
        ),
        // -- Body
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _StatCardsRow(
                  total: total, qualified: qualified,
                  newCount: newCount, conversion: conversion),
              const SizedBox(height: AppConstants.sectionSpacing),
              _ChartsRow(leads: all.toList()),
              const SizedBox(height: AppConstants.sectionSpacing),
              _TableSection(
                searchController: _searchController,
                filterSource: _filterSource,
                filterStatus: _filterStatus,
                sortBy: _sortBy,
                onSearchChanged:  (v) => setState(() => _currentPage = 1),
                onSourceChanged:  (v) => setState(() { _filterSource = v; _currentPage = 1; }),
                onStatusChanged:  (v) => setState(() { _filterStatus = v; _currentPage = 1; }),
                onSortChanged:    (v) => setState(() => _sortBy = v),
                pageItems: _pageItems,
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPageChanged: (p) => setState(() => _currentPage = p),
                onEdit:    (l) => _showDialog(existing: l),
                onDelete:  _confirmDelete,
                onConvert: canConvert ? _showConvertDialog : null,
              ),
              const SizedBox(height: AppConstants.sectionSpacing),
            ]),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Section title widget
// -----------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color textColor;
  const _SectionTitle(this.text, this.icon, this.textColor);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: textColor),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      ]);
}

// -----------------------------------------------------------------------------
// Sticky header delegate
// -----------------------------------------------------------------------------

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Brightness brightness;
  final Color bgColor;
  static const double _h = 80.0;

  const _StickyHeaderDelegate(
      {required this.child, required this.brightness, required this.bgColor});

  @override double get minExtent => _h;
  @override double get maxExtent => _h;

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
              ? Border(bottom: BorderSide(color: AppTheme.border(brightness)))
              : null,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.pagePadding, vertical: 12),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.brightness != brightness || old.bgColor != bgColor || old.child != child;
}

// -----------------------------------------------------------------------------
// Page header bar
// -----------------------------------------------------------------------------

class _PageHeaderBar extends StatelessWidget {
  final VoidCallback onNewTap;
  final bool canCreate;
  const _PageHeaderBar({required this.onNewTap, required this.canCreate});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (_, cst) {
      final narrow = cst.maxWidth < 600;
      final titleBlock = Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: const Icon(Icons.person_search_outlined, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Leads', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('Track, qualify, and convert marketing leads.',
              style: TextStyle(color: textSec, fontSize: 12)),
        ]),
      ]);

      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
        _ExportMenu(),
        if (canCreate) ...[
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onNewTap,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Lead'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ]);

      if (narrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          titleBlock, const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
        ]);
      }
      return Row(children: [titleBlock, const Spacer(), actions]);
    });
  }
}

class _ExportMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const ExportMenuButton(module: 'Leads');
}

// -----------------------------------------------------------------------------
// Stat cards
// -----------------------------------------------------------------------------

class _StatCardsRow extends StatelessWidget {
  final int total, qualified, newCount, conversion;
  const _StatCardsRow(
      {required this.total, required this.qualified,
       required this.newCount, required this.conversion});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, cst) {
      final w = (cst.maxWidth - 3 * AppConstants.itemSpacing) / 4;
      return Wrap(spacing: AppConstants.itemSpacing, runSpacing: AppConstants.itemSpacing, children: [
        SizedBox(width: w, child: _StatCard(title: 'Total Leads',     value: '$total',       icon: Icons.person_search_outlined, color: AppColors.primary)),
        SizedBox(width: w, child: _StatCard(title: 'Qualified Leads',  value: '$qualified',   icon: Icons.verified_outlined,      color: AppColors.success)),
        SizedBox(width: w, child: _StatCard(title: 'New Leads',        value: '$newCount',    icon: Icons.new_releases_outlined,  color: AppColors.info)),
        SizedBox(width: w, child: _StatCard(title: 'Conversion Rate',  value: '$conversion%', icon: Icons.trending_up_rounded,    color: AppColors.warning)),
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
          Expanded(child: Text(title,
              style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 12,
                  fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ]),
        const SizedBox(height: 12),
        Text(value,
            style: TextStyle(
              color: AppTheme.textPrimary(br),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.1,
            )),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Charts row
// -----------------------------------------------------------------------------

class _ChartsRow extends StatelessWidget {
  final List<Lead> leads;
  const _ChartsRow({required this.leads});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, cst) {
      final funnel  = _ChartCard(
          title: 'Lead Funnel',  subtitle: 'Conversion stages overview',
          icon: Icons.filter_list_rounded, iconColor: AppColors.primary,
          child: LeadFunnelChart(leads: leads));
      final sources = _ChartCard(
          title: 'Lead Sources', subtitle: 'Where leads come from',
          icon: Icons.public_rounded,      iconColor: AppColors.info,
          child: LeadSourcesChart(leads: leads));
      if (cst.maxWidth >= 600) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: cst.maxWidth >= 900 ? 2 : 1, child: funnel),
          const SizedBox(width: AppConstants.itemSpacing),
          Expanded(flex: cst.maxWidth >= 900 ? 3 : 1, child: sources),
        ]);
      }
      return Column(children: [funnel, const SizedBox(height: AppConstants.itemSpacing), sources]);
    });
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle,
      required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(color: AppTheme.textPrimary(br), fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Table section
// -----------------------------------------------------------------------------

class _TableSection extends StatelessWidget {
  final TextEditingController searchController;
  final String filterSource, filterStatus, sortBy;
  final ValueChanged<String> onSearchChanged, onSourceChanged, onStatusChanged, onSortChanged;
  final List<Lead> pageItems;
  final int currentPage, totalPages;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Lead> onEdit;
  final ValueChanged<Lead> onDelete;
  final ValueChanged<Lead>? onConvert;

  const _TableSection({
    required this.searchController,
    required this.filterSource, required this.filterStatus, required this.sortBy,
    required this.onSearchChanged, required this.onSourceChanged,
    required this.onStatusChanged, required this.onSortChanged,
    required this.pageItems,
    required this.currentPage, required this.totalPages,
    required this.onPageChanged,
    required this.onEdit,
    required this.onDelete,
    this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final br       = Theme.of(context).brightness;
    final textPri  = AppTheme.textPrimary(br);
    final textSec  = AppTheme.textSecondary(br);
    final fill     = AppTheme.inputFill(br);
    final border   = AppTheme.border(br);
    final dropBg   = AppTheme.surfaceColor(br);

    final sources  = ['All', 'Website', 'Social Media', 'Email', 'Referrals', 'Paid Ads', 'Others'];
    final statuses = ['All', AppConstants.leadNew, AppConstants.leadContacted,
                      AppConstants.leadQualified, AppConstants.leadUnqualified, AppConstants.leadConverted];
    final sorts    = ['Newest', 'Oldest', 'Score High', 'Score Low'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // toolbar
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: TextStyle(fontSize: 13, color: textPri),
              decoration: InputDecoration(
                hintText: 'Search leads�',
                hintStyle: TextStyle(fontSize: 13, color: textSec),
                prefixIcon: Icon(Icons.search, size: 18, color: textSec),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 16, color: textSec),
                        onPressed: () { searchController.clear(); onSearchChanged(''); })
                    : null,
                filled: true, fillColor: fill, contentPadding: EdgeInsets.zero,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Drop(value: filterSource, items: sources,  icon: Icons.public_rounded,     fillColor: fill, borderColor: border, dropColor: dropBg, textColor: textPri, secColor: textSec, onChanged: onSourceChanged),
        const SizedBox(width: 8),
        _Drop(value: filterStatus, items: statuses, icon: Icons.toggle_on_outlined, fillColor: fill, borderColor: border, dropColor: dropBg, textColor: textPri, secColor: textSec, onChanged: onStatusChanged),
        const SizedBox(width: 8),
        _Drop(value: sortBy,       items: sorts,    icon: Icons.sort_rounded,        fillColor: fill, borderColor: border, dropColor: dropBg, textColor: textPri, secColor: textSec, onChanged: onSortChanged),
      ]),
      const SizedBox(height: 12),

      if (pageItems.isEmpty)
        _EmptyState()
      else
        LayoutBuilder(builder: (_, cst) {
          if (cst.maxWidth < 700) {
            return Column(children: pageItems.map((l) => _MobileCard(
              lead: l,
              onEdit: onEdit,
              onDelete: onDelete,
              onConvert: onConvert,
            )).toList());
          }
          return _DesktopTable(
            leads: pageItems,
            onEdit: onEdit,
            onDelete: onDelete,
            onConvert: onConvert,
          );
        }),

      if (pageItems.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Pagination(currentPage: currentPage, totalPages: totalPages, onPageChanged: onPageChanged),
      ],
    ]);
  }
}

// small toolbar dropdown
class _Drop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final Color fillColor, borderColor, dropColor, textColor, secColor;
  final ValueChanged<String> onChanged;

  const _Drop({required this.value, required this.items, required this.icon,
      required this.fillColor, required this.borderColor, required this.dropColor,
      required this.textColor, required this.secColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isDense: true,
          dropdownColor: dropColor,
          icon: Icon(icon, size: 16, color: AppColors.primary),
          style: TextStyle(fontSize: 12, color: textColor),
          items: items.map((i) => DropdownMenuItem(
            value: i,
            child: Text(i, style: TextStyle(fontSize: 12, color: textColor)),
          )).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// dialog dropdown with label
class _DlgDrop extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final Color fillColor, borderColor, dropColor, textColor, secColor;
  final ValueChanged<String> onChanged;

  const _DlgDrop({required this.label, required this.value, required this.items,
      required this.fillColor, required this.borderColor, required this.dropColor,
      required this.textColor, required this.secColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isDense: true, isExpanded: true,
            dropdownColor: dropColor,
            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: secColor),
            style: TextStyle(fontSize: 13, color: textColor),
            items: items.map((i) => DropdownMenuItem(
              value: i,
              child: Text(i, style: TextStyle(fontSize: 13, color: textColor)),
            )).toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Desktop table � now with Edit, Convert, Delete actions
// -----------------------------------------------------------------------------

class _DesktopTable extends StatelessWidget {
  final List<Lead> leads;
  final ValueChanged<Lead> onEdit;
  final ValueChanged<Lead> onDelete;
  final ValueChanged<Lead>? onConvert;

  const _DesktopTable({
    required this.leads,
    required this.onEdit,
    required this.onDelete,
    this.onConvert,
  });

  Color _scoreColor(int s) =>
      s >= 80 ? AppColors.success : (s >= 50 ? AppColors.warning : AppColors.danger);

  @override
  Widget build(BuildContext context) {
    final br       = Theme.of(context).brightness;
    final headerBg = AppTheme.tableHeaderColor(br);
    final rowBg    = AppTheme.cardColor(br);
    final hoverBg  = AppTheme.tableRowHover(br);
    final textPri  = AppTheme.textPrimary(br);
    final textSec  = AppTheme.textSecondary(br);
    final borderCol = AppTheme.border(br);

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1100),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(headerBg),
              dataRowColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.hovered) ? hoverBg : rowBg),
              columns: [
                DataColumn(label: Text('Lead',        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Company',     style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Source',      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Score',       style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Assigned To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Status',      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Priority',    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
                DataColumn(label: Text('Actions',     style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec))),
              ],
              rows: leads.map((l) {
                final sc = _scoreColor(l.score);
                final priBg   = l.priority == 'High'   ? AppTheme.dangerBg(br)  :
                                l.priority == 'Medium' ? AppTheme.warningBg(br) : AppTheme.infoBg(br);
                final priText = l.priority == 'High'   ? AppColors.danger  :
                                l.priority == 'Medium' ? AppColors.warning : AppColors.info;
                final canBeConverted = l.status == AppConstants.leadQualified && onConvert != null;

                return DataRow(cells: [
                  DataCell(Row(children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        l.name.split(' ').take(2).map((w) => w[0].toUpperCase()).join(),
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPri),
                        overflow: TextOverflow.ellipsis)),
                  ])),
                  DataCell(Text(l.company,    style: TextStyle(fontSize: 13, color: textPri), overflow: TextOverflow.ellipsis)),
                  DataCell(Text(l.source,     style: TextStyle(fontSize: 13, color: textPri))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Text('${l.score}',
                        style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.w700)),
                  )),
                  DataCell(Text(l.assignedTo, style: TextStyle(fontSize: 13, color: textPri), overflow: TextOverflow.ellipsis)),
                  DataCell(StatusBadge(status: l.status)),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priBg,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Text(l.priority,
                        style: TextStyle(color: priText, fontSize: 11, fontWeight: FontWeight.w600)),
                  )),
                  // -- Actions cell
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      color: AppColors.primary,
                      tooltip: 'Edit',
                      onPressed: () => onEdit(l),
                    ),
                    if (canBeConverted)
                      IconButton(
                        icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                        color: AppColors.success,
                        tooltip: 'Convert to Opportunity',
                        onPressed: () => onConvert!(l),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 17),
                      color: AppColors.danger,
                      tooltip: 'Delete',
                      onPressed: () => onDelete(l),
                    ),
                  ])),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mobile card � with context menu for edit / convert / delete
// -----------------------------------------------------------------------------

class _MobileCard extends StatelessWidget {
  final Lead lead;
  final ValueChanged<Lead> onEdit;
  final ValueChanged<Lead> onDelete;
  final ValueChanged<Lead>? onConvert;

  const _MobileCard({
    required this.lead,
    required this.onEdit,
    required this.onDelete,
    this.onConvert,
  });

  Color _scoreColor(int s) =>
      s >= 80 ? AppColors.success : (s >= 50 ? AppColors.warning : AppColors.danger);

  @override
  Widget build(BuildContext context) {
    final br       = Theme.of(context).brightness;
    final cardBg   = AppTheme.cardColor(br);
    final borderCol = AppTheme.border(br);
    final textPri  = AppTheme.textPrimary(br);
    final textSec  = AppTheme.textSecondary(br);
    final chipBg   = AppTheme.surfaceVariant(br);
    final sc       = _scoreColor(lead.score);
    final canBeConverted = lead.status == AppConstants.leadQualified && onConvert != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              lead.name.split(' ').take(2).map((w) => w[0].toUpperCase()).join(),
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lead.name,    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPri)),
            Text(lead.company, style: TextStyle(fontSize: 12, color: textSec)),
          ])),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textSec, size: 20),
            color: AppTheme.surfaceColor(br),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              side: BorderSide(color: borderCol),
            ),
            onSelected: (v) {
              if (v == 'edit')    onEdit(lead);
              if (v == 'convert') onConvert?.call(lead);
              if (v == 'delete')  onDelete(lead);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Row(children: [
                const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Edit'),
              ])),
              if (canBeConverted) PopupMenuItem(value: 'convert', child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                const Text('Convert to Opportunity'),
              ])),
              PopupMenuItem(value: 'delete', child: Row(children: [
                const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
              ])),
            ],
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Chip(icon: Icons.public_rounded,    label: lead.source,           chipBg: chipBg, borderCol: borderCol, textColor: textPri, iconColor: textSec),
          _Chip(icon: Icons.star_outline,       label: 'Score: ${lead.score}', chipBg: chipBg, borderCol: borderCol, textColor: textPri, iconColor: textSec),
          StatusBadge(status: lead.status),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            ),
            child: Text(lead.priority,
                style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color chipBg, borderCol, textColor, iconColor;
  const _Chip({required this.icon, required this.label, required this.chipBg,
      required this.borderCol, required this.textColor, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: borderCol),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: iconColor),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: textColor)),
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// Empty state, pagination
// -----------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Center(child: Column(children: [
        Icon(Icons.person_search_outlined, size: 48,
            color: AppTheme.textSecondary(br).withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('No leads found',
            style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 14)),
      ])),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int currentPage, totalPages;
  final ValueChanged<int> onPageChanged;
  const _Pagination(
      {required this.currentPage, required this.totalPages, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    final br       = Theme.of(context).brightness;
    final textSec  = AppTheme.textSecondary(br);
    final pageBg   = AppTheme.surfaceVariant(br);
    final borderCol = AppTheme.border(br);

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      IconButton(
        icon: const Icon(Icons.chevron_left_rounded, size: 20),
        onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
        color: textSec,
      ),
      ...List.generate(totalPages, (i) {
        final page     = i + 1;
        final isActive = page == currentPage;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () => onPageChanged(page),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : pageBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isActive ? AppColors.primary : borderCol),
              ),
              child: Center(child: Text('$page',
                  style: TextStyle(
                    color: isActive ? Colors.white : textSec,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ))),
            ),
          ),
        );
      }),
      IconButton(
        icon: const Icon(Icons.chevron_right_rounded, size: 20),
        onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
        color: textSec,
      ),
    ]);
  }
}
