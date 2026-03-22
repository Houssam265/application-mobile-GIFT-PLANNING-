class AppLinks {
  // Peut être surchargé au build avec:
  // flutter build web --dart-define=APP_BASE_URL=https://giftplan.rf.gd
  static const String baseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: 'https://giftplan.rf.gd',
  );

  static String joinUrl(String code) => '$baseUrl/join/$code';
}
