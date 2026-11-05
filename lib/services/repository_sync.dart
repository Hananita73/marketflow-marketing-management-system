import '../models/budget.dart';
import '../models/budget_request.dart';
import '../models/campaign.dart';
import '../models/campaign_customer.dart';
import '../models/content_item.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/influencer.dart';
import '../models/lead.dart';
import '../models/notification_model.dart';
import '../models/opportunity.dart';
import '../models/promotion.dart';
import '../models/sms_campaign.dart';

/// Reloads the application repositories after authentication.
///
/// The first application boot can happen before a user has signed in. In that
/// state Supabase correctly rejects authenticated table reads, so the app
/// keeps its bundled fallback data. Once a session exists we must fetch again;
/// otherwise the dashboard would continue showing the fallback snapshot.
class RepositorySync {
  RepositorySync._();

  static Future<void> reloadAll() async {
    Future<void> safe(Future<void> Function() load) async {
      try {
        await load();
      } catch (_) {
        // One unavailable table must not prevent the remaining modules from
        // becoming live.
      }
    }

    await Future.wait([
      safe(() => CampaignRepository.init(force: true)),
      safe(() => CustomerRepository.init(force: true)),
      safe(() => LeadRepository.init(force: true)),
      safe(() => OpportunityRepository.init(force: true)),
      safe(() => BudgetRepository.init(force: true)),
      safe(() => PromotionRepository.init(force: true)),
      safe(() => InfluencerRepository.init(force: true)),
      safe(() => ContentRepository.init(force: true)),
      // Notifications are user-specific — reload after auth so we get the
      // right user's notifications, not the anonymous seed data.
      safe(() => NotificationRepository.init(force: true)),
      // SMS campaigns
      safe(() => SmsCampaignRepository.init(force: true)),
      // Budget requests
      safe(() => BudgetRequestRepository.init(force: true)),
    ]);

    await Future.wait([
      safe(() => CampaignCustomerRepository.init(force: true)),
      safe(() => ExpenseRepository.init(force: true)),
    ]);
  }
}
