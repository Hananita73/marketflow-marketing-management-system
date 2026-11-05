import '../core/constants.dart';
import '../services/entity_remote_stores.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROMOTION / COUPON — canonical model for the Promotions module.
//
// Moved out of lib/models/app_models.dart so it can live beside its
// Supabase-wired repository, mirroring the budget module layout.
// Persisted in the Supabase `promotions` table.
// ═══════════════════════════════════════════════════════════════════════════

class Promotion {
  final String id;
  final String name;
  final String type;
  final String discount;
  final double discountValue;
  final DateTime startDate;
  final DateTime endDate;
  final int usageLimit;
  final int usedCount;
  final String status;
  final String campaignName;
  final List<String> couponCodes;

  const Promotion({
    required this.id,
    required this.name,
    required this.type,
    required this.discount,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    required this.usageLimit,
    required this.usedCount,
    required this.status,
    required this.campaignName,
    required this.couponCodes,
  });

  double get usagePercent => usageLimit > 0 ? usedCount / usageLimit : 0;
}

class PromotionRepository {
  PromotionRepository._();

  static final List<Promotion> _data = [
    Promotion(id: 'PR001', name: 'Summer Flash Sale', type: 'Percentage', discount: '30% off', discountValue: 30, startDate: DateTime(2026, 5, 10), endDate: DateTime(2026, 6, 30), usageLimit: 1000, usedCount: 512, status: AppConstants.statusActive, campaignName: 'Summer Sale Promo', couponCodes: ['SUMMER30', 'FLASH30']),
    Promotion(id: 'PR002', name: 'Launch Day Offer', type: 'Percentage', discount: '20% off', discountValue: 20, startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31), usageLimit: 500, usedCount: 342, status: AppConstants.statusActive, campaignName: 'Product Launch 2026', couponCodes: ['LAUNCH20']),
    Promotion(id: 'PR003', name: 'Early Bird Discount', type: 'Percentage', discount: '15% off', discountValue: 15, startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 15), usageLimit: 200, usedCount: 198, status: AppConstants.statusCompleted, campaignName: 'Product Launch 2026', couponCodes: ['EARLY15']),
    Promotion(id: 'PR004', name: 'Win-Back Offer', type: 'Percentage', discount: '10% off', discountValue: 10, startDate: DateTime(2026, 4, 1), endDate: DateTime(2026, 4, 30), usageLimit: 300, usedCount: 74, status: AppConstants.statusPaused, campaignName: 'Re-engagement Campaign', couponCodes: ['COMEBACK10']),
    Promotion(id: 'PR005', name: 'Loyalty Reward', type: 'Fixed Amount', discount: 'ETB 500 off', discountValue: 500, startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 8, 31), usageLimit: 150, usedCount: 0, status: AppConstants.statusDraft, campaignName: 'Brand Awareness Q3', couponCodes: ['LOYAL500']),
    Promotion(id: 'PR006', name: 'Referral Bonus', type: 'Percentage', discount: '25% off', discountValue: 25, startDate: DateTime(2026, 5, 15), endDate: DateTime(2026, 7, 15), usageLimit: 400, usedCount: 128, status: AppConstants.statusActive, campaignName: 'Lead Gen — SME', couponCodes: ['REFER25', 'REF25B']),
  ];

  static bool _initialized = false;

  /// Loads promotions from Supabase once at startup (called from main.dart).
  /// Falls back to bundled seed data when the backend is unreachable; seeds
  /// the remote table from local data on first run when it is empty.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await PromotionRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await PromotionRemoteStore.seed(_data);
    } else {
      _data
        ..clear()
        ..addAll(remote);
    }
  }

  static List<Promotion> getAll() => List.unmodifiable(_data);

  static Promotion? findById(String id) {
    try {
      return _data.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(Promotion promotion) {
    _data.add(promotion);
    // Persist to database (fire-and-forget, fails silently in offline mode)
    PromotionRemoteStore.upsert(promotion)
      .then((_) {
        // Promotion persisted to database
      })
      .onError((_, _) {
        // Failed to persist - running in offline mode, local data remains valid
      });
  }

  static void update(Promotion promotion) {
    final idx = _data.indexWhere((p) => p.id == promotion.id);
    if (idx != -1) {
      _data[idx] = promotion;
      // Persist to database (fire-and-forget, fails silently in offline mode)
      PromotionRemoteStore.upsert(promotion)
        .then((_) {
          // Promotion persisted to database
        })
        .onError((_, _) {
          // Failed to persist - running in offline mode, local data remains valid
        });
    }
  }

  static void remove(String id) {
    _data.removeWhere((p) => p.id == id);
    PromotionRemoteStore.delete(id); // fire-and-forget sync
  }

  static String nextId() {
    if (_data.isEmpty) return 'PR001';
    final maxNum = _data
        .map((p) => int.tryParse(p.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'PR${(maxNum + 1).toString().padLeft(3, '0')}';
  }
}
