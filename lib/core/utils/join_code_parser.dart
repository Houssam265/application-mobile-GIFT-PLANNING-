/// Extrait un [code_partage] depuis une saisie brute : code seul, URL https, lien giftplan://
String? extractJoinCode(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  s = s.split('\n').first.trim();

  final lower = s.toLowerCase();
  final joinIdx = lower.indexOf('/join/');
  if (joinIdx != -1) {
    final rest = s.substring(joinIdx + 6).split(RegExp(r'[/?#]')).first;
    if (rest.isNotEmpty && RegExp(r'^[A-Za-z0-9]+$').hasMatch(rest)) {
      return rest.toUpperCase();
    }
  }

  final uri = Uri.tryParse(s);
  if (uri != null) {
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final segs = uri.pathSegments;
      for (var i = 0; i < segs.length - 1; i++) {
        if (segs[i].toLowerCase() == 'join') {
          final c = segs[i + 1].split('?').first;
          if (c.isNotEmpty) return c.toUpperCase();
        }
      }
    }
    if (uri.scheme == 'giftplan' && uri.host == 'join' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first.split('?').first.toUpperCase();
    }
  }

  final plain = s.split('?').first.trim();
  if (RegExp(r'^[A-Za-z0-9]{6,16}$').hasMatch(plain)) {
    return plain.toUpperCase();
  }
  return null;
}
