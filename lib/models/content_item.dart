import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../services/entity_remote_stores.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONTENT ITEM — canonical model for the Content module.
//
// Moved out of lib/models/app_models.dart and wired to the Supabase
// `content_items` table.
// ═══════════════════════════════════════════════════════════════════════════

class ContentItem {
  final String id;
  final String title;
  final String type;
  final String channel;
  final String creator;
  final String status;
  final DateTime scheduledDate;
  final String campaignName;
  final String description;
  final int views;
  final int clicks;

  const ContentItem({
    required this.id,
    required this.title,
    required this.type,
    required this.channel,
    required this.creator,
    required this.status,
    required this.scheduledDate,
    required this.campaignName,
    required this.description,
    required this.views,
    required this.clicks,
  });

  IconData get typeIcon {
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

  Color get typeColor {
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
}

class ContentRepository {
  ContentRepository._();

  static final List<ContentItem> _data = [
    ContentItem(id: 'CN001', title: 'How to Boost Your Marketing ROI in 2026', type: 'Blog Post', channel: 'Website', creator: 'Sara M.', status: AppConstants.statusActive, scheduledDate: DateTime(2026, 5, 10), campaignName: 'Brand Awareness Q3', description: 'Comprehensive guide on modern marketing ROI tactics.', views: 3240, clicks: 412),
    ContentItem(id: 'CN002', title: 'Product Launch Announcement Video', type: 'Video', channel: 'YouTube', creator: 'Yonas B.', status: AppConstants.statusActive, scheduledDate: DateTime(2026, 5, 1), campaignName: 'Product Launch 2026', description: 'Official product launch video for the mobile app.', views: 18500, clicks: 2100),
    ContentItem(id: 'CN003', title: 'Summer Sale Instagram Carousel', type: 'Social Post', channel: 'Instagram', creator: 'Dawit A.', status: AppConstants.statusDraft, scheduledDate: DateTime(2026, 5, 15), campaignName: 'Summer Sale Promo', description: '5-slide carousel showcasing summer discounts.', views: 0, clicks: 0),
    ContentItem(id: 'CN004', title: 'Newsletter #12 — May 2026', type: 'Email', channel: 'Email', creator: 'Sara M.', status: AppConstants.statusActive, scheduledDate: DateTime(2026, 5, 8), campaignName: 'Re-engagement Campaign', description: 'Monthly newsletter with product updates and tips.', views: 9800, clicks: 1540),
    ContentItem(id: 'CN005', title: 'SME Marketing Guide Infographic', type: 'Infographic', channel: 'LinkedIn', creator: 'Yonas B.', status: AppConstants.statusCompleted, scheduledDate: DateTime(2026, 4, 20), campaignName: 'Lead Gen — SME', description: 'Visual guide to SME marketing best practices.', views: 5600, clicks: 890),
    ContentItem(id: 'CN006', title: 'Live Webinar: Digital Marketing Trends', type: 'Webinar', channel: 'Zoom', creator: 'Dawit A.', status: AppConstants.statusPaused, scheduledDate: DateTime(2026, 6, 5), campaignName: 'Brand Awareness Q3', description: 'Monthly webinar exploring current digital trends.', views: 0, clicks: 320),
    ContentItem(id: 'CN007', title: 'TikTok Brand Story', type: 'Video', channel: 'TikTok', creator: 'Sara M.', status: AppConstants.statusActive, scheduledDate: DateTime(2026, 5, 12), campaignName: 'Influencer Collab Q2', description: 'Short-form brand storytelling video for TikTok.', views: 42000, clicks: 3800),
  ];

  static bool _initialized = false;

  /// Loads content items from Supabase once at startup (called from main.dart).
  /// Falls back to bundled seed data when the backend is unreachable; seeds
  /// the remote table from local data on first run when it is empty.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await ContentRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await ContentRemoteStore.seed(_data);
    } else {
      _data
        ..clear()
        ..addAll(remote);
    }
  }

  static List<ContentItem> getAll() => List.unmodifiable(_data);

  static ContentItem? findById(String id) {
    try {
      return _data.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(ContentItem item) {
    _data.add(item);
    // Persist to database (fire-and-forget, fails silently in offline mode)
    ContentRemoteStore.upsert(item)
      .then((_) {
        // Content item persisted to database
      })
      .onError((_, _) {
        // Failed to persist - running in offline mode, local data remains valid
      });
  }

  static void update(ContentItem item) {
    final idx = _data.indexWhere((c) => c.id == item.id);
    if (idx != -1) {
      _data[idx] = item;
      // Persist to database (fire-and-forget, fails silently in offline mode)
      ContentRemoteStore.upsert(item)
        .then((_) {
          // Content item persisted to database
        })
        .onError((_, _) {
          // Failed to persist - running in offline mode, local data remains valid
        });
    }
  }

  static void remove(String id) {
    _data.removeWhere((c) => c.id == id);
    ContentRemoteStore.delete(id); // fire-and-forget sync
  }

  static String nextId() {
    if (_data.isEmpty) return 'CN001';
    final maxNum = _data
        .map((c) => int.tryParse(c.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'CN${(maxNum + 1).toString().padLeft(3, '0')}';
  }
}
