// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalPanel
//
// A reusable card section that shows a list of items pending approval.
// Used by Budget, Campaign, and Promotion screens.
//
// Usage:
//   ApprovalPanel<T>(
//     title: 'Budget Requests',
//     icon: Icons.request_page_outlined,
//     items: pending,
//     itemBuilder: (ctx, item) => ApprovalCard(...),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalPanel<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<T> items;
  final Widget Function(BuildContext ctx, T item) itemBuilder;
  final Widget? emptyWidget;

  const ApprovalPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    final br      = Theme.of(context).brightness;
    final cardBg  = AppTheme.cardColor(br);
    final borderC = AppTheme.border(br);
    final textPri = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderC),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppConstants.radiusLarge),
              topRight: Radius.circular(AppConstants.radiusLarge),
            ),
            border: Border(bottom: BorderSide(color: borderC)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Icon(icon, color: AppColors.warning, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPri)),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${items.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              Text(subtitle, style: TextStyle(fontSize: 11, color: textSec)),
            ])),
          ]),
        ),
        // Items
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: emptyWidget ??
                Center(child: Column(children: [
                  Icon(Icons.check_circle_outline,
                      size: 36, color: AppColors.success.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text('No pending approvals',
                      style: TextStyle(color: textSec, fontSize: 13)),
                ])),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: borderC),
            itemBuilder: (ctx, i) => itemBuilder(ctx, items[i]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalActionRow — approve / reject buttons used inside approval cards
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalActionRow extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool loading;

  const ApprovalActionRow({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: loading ? null : onReject,
            icon: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Reject', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: loading ? null : onApprove,
            icon: loading
                ? const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 14),
            label: const Text('Approve', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// RejectReasonDialog — shared dialog for entering rejection comments
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> showRejectDialog(BuildContext context, {String title = 'Reject Request'}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final br      = Theme.of(ctx).brightness;
      final textPri = AppTheme.textPrimary(br);
      final textSec = AppTheme.textSecondary(br);
      return AlertDialog(
        backgroundColor: AppTheme.surfaceColor(br),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          side: BorderSide(color: AppTheme.border(br)),
        ),
        title: Row(children: [
          const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Please provide a reason for rejection:',
              style: TextStyle(color: textSec, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: textPri),
            decoration: InputDecoration(
              hintText: 'Enter reason…',
              hintStyle: TextStyle(color: textSec),
              filled: true,
              fillColor: AppTheme.inputFill(br),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(color: AppTheme.border(br)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final reason = ctrl.text.trim();
              Navigator.pop(ctx, reason.isEmpty ? '(No reason given)' : reason);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      );
    },
  );
}
