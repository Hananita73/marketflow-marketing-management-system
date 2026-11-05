import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../services/entity_remote_stores.dart';

// ═══════════════════════════════════════════════════════════════════════════
// INFLUENCER — canonical model for the Influencers module.
//
// Moved out of lib/models/app_models.dart and wired to the Supabase
// `influencers` table. avatarColor is derived deterministically from the id
// (stable across restarts, no need to persist Flutter Color objects).
// ═══════════════════════════════════════════════════════════════════════════

class Influencer {
  final String id;
  final String name;
  final String handle;
  final String platform;
  final int followers;
  final double engagementRate;
  final String category;
  final String status;
  final double costPerPost;
  final String campaignName;
  final String avatarInitials;

  const Influencer({
    required this.id,
    required this.name,
    required this.handle,
    required this.platform,
    required this.followers,
    required this.engagementRate,
    required this.category,
    required this.status,
    required this.costPerPost,
    required this.campaignName,
    required this.avatarInitials,
  });

  /// Stable per-id color from the shared chart palette.
  Color get avatarColor =>
      AppColors.chartPalette[id.hashCode.abs() % AppColors.chartPalette.length];

  String get followersLabel {
    if (followers >= 1000000) return '${(followers / 1000000).toStringAsFixed(1)}M';
    if (followers >= 1000) return '${(followers / 1000).toStringAsFixed(0)}K';
    return '$followers';
  }
}

class InfluencerRepository {
  InfluencerRepository._();

  static final List<Influencer> _data = [
    Influencer(id: 'INF001', name: 'Abel Tafesse', handle: '@abeltafesse', platform: 'Instagram', followers: 245000, engagementRate: 5.8, category: 'Tech', status: AppConstants.statusActive, costPerPost: 12000, campaignName: 'Product Launch 2026', avatarInitials: 'AT'),
    Influencer(id: 'INF002', name: 'Tizita Habte', handle: '@tizitah', platform: 'TikTok', followers: 890000, engagementRate: 8.2, category: 'Lifestyle', status: AppConstants.statusActive, costPerPost: 28000, campaignName: 'Summer Sale Promo', avatarInitials: 'TH'),
    Influencer(id: 'INF003', name: 'Kidus Mamo', handle: '@kidusmamo', platform: 'YouTube', followers: 120000, engagementRate: 4.1, category: 'Gaming', status: AppConstants.statusPaused, costPerPost: 8500, campaignName: 'Brand Awareness Q3', avatarInitials: 'KM'),
    Influencer(id: 'INF004', name: 'Mekdes Alemu', handle: '@mekdesalemu', platform: 'Instagram', followers: 310000, engagementRate: 6.5, category: 'Fashion', status: AppConstants.statusActive, costPerPost: 16000, campaignName: 'Influencer Collab Q2', avatarInitials: 'MA'),
    Influencer(id: 'INF005', name: 'Yonas Getachew', handle: '@yonasgetachew', platform: 'Twitter', followers: 78000, engagementRate: 3.4, category: 'Business', status: AppConstants.statusCompleted, costPerPost: 5500, campaignName: 'Lead Gen — SME', avatarInitials: 'YG'),
    Influencer(id: 'INF006', name: 'Feven Tadesse', handle: '@feventadesse', platform: 'TikTok', followers: 1200000, engagementRate: 9.1, category: 'Beauty', status: AppConstants.statusActive, costPerPost: 45000, campaignName: 'Product Launch 2026', avatarInitials: 'FT'),
  ];

  static bool _initialized = false;

  /// Loads influencers from Supabase once at startup (called from main.dart).
  /// Falls back to bundled seed data when the backend is unreachable; seeds
  /// the remote table from local data on first run when it is empty.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await InfluencerRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await InfluencerRemoteStore.seed(_data);
    } else {
      _data
        ..clear()
        ..addAll(remote);
    }
  }

  static List<Influencer> getAll() => List.unmodifiable(_data);

  static Influencer? findById(String id) {
    try {
      return _data.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(Influencer influencer) {
    _data.add(influencer);
    // Persist to database (fire-and-forget, fails silently in offline mode)
    InfluencerRemoteStore.upsert(influencer)
      .then((_) {
        // Influencer persisted to database
      })
      .onError((_, _) {
        // Failed to persist - running in offline mode, local data remains valid
      });
  }

  static void update(Influencer influencer) {
    final idx = _data.indexWhere((i) => i.id == influencer.id);
    if (idx != -1) {
      _data[idx] = influencer;
      // Persist to database (fire-and-forget, fails silently in offline mode)
      InfluencerRemoteStore.upsert(influencer)
        .then((_) {
          // Influencer persisted to database
        })
        .onError((_, _) {
          // Failed to persist - running in offline mode, local data remains valid
        });
    }
  }

  static void remove(String id) {
    _data.removeWhere((i) => i.id == id);
    InfluencerRemoteStore.delete(id); // fire-and-forget sync
  }

  static String nextId() {
    if (_data.isEmpty) return 'INF001';
    final maxNum = _data
        .map((i) => int.tryParse(i.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'INF${(maxNum + 1).toString().padLeft(3, '0')}';
  }
}
