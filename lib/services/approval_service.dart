// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../models/campaign.dart';
import '../models/budget_request.dart';
import '../services/audit_log_service.dart';
import '../services/auth_service.dart';
import '../services/access_service.dart';
import '../widgets/common/approval_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalService
//
// Centralised approval workflow for campaigns and budget requests.
//
// RULES enforced here (backed by DB RLS):
//   1. Only Marketing Manager and Administrator can approve.
//   2. A user CANNOT approve their own submission (self-approval prevention).
//   3. Items must be in 'Pending Approval' to be approved/rejected.
//   4. Approved  → 'Approved'
//      Rejected  → 'Rejected'
//      Changes   → 'Changes Requested'  (submitter can re-edit and re-submit)
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalService {
  ApprovalService._();

  // ══════════════════════════════════════════════════════════════════════════
  // Campaign Workflow
  // ══════════════════════════════════════════════════════════════════════════

  /// Marketing Clerk submits a draft / changes-requested campaign for approval.
  static bool submitCampaign(BuildContext context, String campaignId) {
    if (!AccessService.requireSubmit(context, 'Campaigns')) return false;
    final c = CampaignRepository.findById(campaignId);
    if (c == null) return false;
    if (c.status != AppConstants.statusDraft &&
        c.status != AppConstants.statusChangesRequested) {
      _snack(context,
          'Only Draft or Changes Requested campaigns can be submitted.',
          color: AppColors.warning);
      return false;
    }
    final submitter = AuthService().currentName;
    CampaignRepository.update(c.copyWith(
      status: AppConstants.statusPendingApproval,
      approvedBy: '',
      approvalComments: '',
      submittedBy: submitter,
    ));
    AuditLogService.logSubmit('Campaigns', campaignId, c.name,
        details: {'submitted_by': submitter});
    _snack(context, '"${c.name}" submitted for approval.');
    return true;
  }

  /// Marketing Manager (or Admin) approves a pending campaign.
  static Future<bool> approveCampaign(
      BuildContext context, String campaignId) async {
    if (!_guardApprover(context)) return false;
    final c = CampaignRepository.findById(campaignId);
    if (c == null) return false;
    if (!_guardNotSelf(context, c.submittedBy)) return false;
    if (c.status != AppConstants.statusPendingApproval) {
      _snack(context, 'This campaign is not pending approval.',
          color: AppColors.warning);
      return false;
    }
    final approver = AuthService().currentName;
    CampaignRepository.approveCampaign(campaignId, approver);
    AuditLogService.logApprove('Campaigns', campaignId, c.name,
        details: {'approved_by': approver});
    _snack(context, '"${c.name}" approved.', color: AppColors.success);
    return true;
  }

  /// Marketing Manager (or Admin) rejects a pending campaign.
  static Future<bool> rejectCampaign(
      BuildContext context, String campaignId) async {
    if (!_guardApprover(context)) return false;
    final c = CampaignRepository.findById(campaignId);
    if (c == null) return false;
    if (!_guardNotSelf(context, c.submittedBy)) return false;
    if (c.status != AppConstants.statusPendingApproval) {
      _snack(context, 'This campaign is not pending approval.',
          color: AppColors.warning);
      return false;
    }
    final reason = await showRejectDialog(context, title: 'Reject Campaign');
    if (reason == null) return false;
    final approver = AuthService().currentName;
    CampaignRepository.rejectCampaign(campaignId, approver, reason);
    AuditLogService.logReject('Campaigns', campaignId, c.name,
        details: {'rejected_by': approver, 'reason': reason});
    _snack(context, '"${c.name}" rejected.', color: AppColors.warning);
    return true;
  }

  /// Marketing Manager (or Admin) requests changes on a pending campaign.
  static Future<bool> requestChangesCampaign(
      BuildContext context, String campaignId) async {
    if (!_guardApprover(context)) return false;
    final c = CampaignRepository.findById(campaignId);
    if (c == null) return false;
    if (!_guardNotSelf(context, c.submittedBy)) return false;
    final comments =
        await showRejectDialog(context, title: 'Request Changes');
    if (comments == null) return false;
    final approver = AuthService().currentName;
    CampaignRepository.update(c.copyWith(
      status: AppConstants.statusChangesRequested,
      approvedBy: approver,
      approvalComments: comments,
    ));
    AuditLogService.log(
      action: 'changes_requested',
      module: 'Campaigns',
      recordId: campaignId,
      recordName: c.name,
      details: {'by': approver, 'comments': comments},
    );
    _snack(context, 'Changes requested for "${c.name}".',
        color: AppColors.info);
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Budget Request Workflow
  // ══════════════════════════════════════════════════════════════════════════

  static Future<bool> approveBudgetRequest(
      BuildContext context, String reqId) async {
    if (!_guardApprover(context)) return false;
    final req = BudgetRequestRepository.findById(reqId);
    if (req == null) return false;
    if (!_guardNotSelf(context, req.requestedBy)) return false;
    if (req.status != 'Pending') {
      _snack(context, 'This request is not pending approval.',
          color: AppColors.warning);
      return false;
    }
    final approver = AuthService().currentName;
    BudgetRequestRepository.update(req.copyWith(
      status: 'Approved',
      reviewedBy: approver,
      reviewComments: 'Approved',
      reviewedAt: DateTime.now(),
    ));
    AuditLogService.logApprove('Budget', reqId, 'Budget Request $reqId',
        details: {'approved_by': approver, 'amount': req.requestedAmount});
    _snack(context, 'Budget request approved.', color: AppColors.success);
    return true;
  }

  static Future<bool> rejectBudgetRequest(
      BuildContext context, String reqId) async {
    if (!_guardApprover(context)) return false;
    final req = BudgetRequestRepository.findById(reqId);
    if (req == null) return false;
    if (!_guardNotSelf(context, req.requestedBy)) return false;
    if (req.status != 'Pending') {
      _snack(context, 'This request is not pending approval.',
          color: AppColors.warning);
      return false;
    }
    final reason =
        await showRejectDialog(context, title: 'Reject Budget Request');
    if (reason == null) return false;
    final approver = AuthService().currentName;
    BudgetRequestRepository.update(req.copyWith(
      status: 'Rejected',
      reviewedBy: approver,
      reviewComments: reason,
      reviewedAt: DateTime.now(),
    ));
    AuditLogService.logReject('Budget', reqId, 'Budget Request $reqId',
        details: {'rejected_by': approver, 'reason': reason});
    _snack(context, 'Budget request rejected.', color: AppColors.warning);
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Internal guards
  // ══════════════════════════════════════════════════════════════════════════

  /// Only Marketing Managers and Administrators can approve.
  static bool _guardApprover(BuildContext context) {
    if (AccessService.isApprover) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Only Marketing Managers can approve items.'),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
    return false;
  }

  /// Prevents a user from approving their own submission.
  static bool _guardNotSelf(BuildContext context, String submitterName) {
    final current = AuthService().currentName;
    if (current.isNotEmpty &&
        submitterName.isNotEmpty &&
        current == submitterName) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You cannot approve your own submission.'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return false;
    }
    return true;
  }

  static void _snack(BuildContext context, String msg,
      {Color color = AppColors.success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
