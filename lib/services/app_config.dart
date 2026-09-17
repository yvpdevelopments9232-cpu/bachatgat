class AppConfig {
  /// Set to true when running in local-first database mode (Offline or Hybrid).
  static bool isOfflineMode = false;

  /// Set to true when running the Hybrid Auto-Sync Edition.
  static bool isHybridMode = false;

  /// True strictly when running in 100% Offline standalone mode
  static bool get isOfflineOnly => isOfflineMode && !isHybridMode;

  /// True strictly when running in 100% Online Supabase Cloud mode
  static bool get isOnlineMode => !isOfflineMode && !isHybridMode;

  /// Lowercase edition identifier
  static String get edition => isHybridMode ? 'hybrid' : (isOfflineMode ? 'offline' : 'online');

  /// Human-friendly edition display name
  static String get editionName {
    if (isHybridMode) return 'हायब्रिड ऑटो-सिंक (Hybrid Auto-Sync)';
    if (isOfflineMode) return 'ऑफलाइन आवृत्ती (Offline Standalone)';
    return 'क्लाउड ऑनलाइन (Cloud Online)';
  }

  /// Compact uppercase badge tag
  static String get editionBadge {
    if (isHybridMode) return 'HYBRID';
    if (isOfflineMode) return 'OFFLINE';
    return 'ONLINE';
  }

  /// Prefix for shared preferences keys to isolate sessions between editions
  static String get sessionPrefix {
    if (isHybridMode) return 'hybrid_';
    if (isOfflineMode) return 'offline_';
    return 'online_';
  }

  /// Returns an edition-isolated key for SharedPreferences
  static String prefKey(String key) => '$sessionPrefix$key';
}
