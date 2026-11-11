/// Convierte "1.2.3", "v1.2.3" o "1.2.3+4" en [1, 2, 3]. Devuelve null si no es válida.
List<int>? parsearVersion(String texto) {
  final limpio = texto
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+-]'))
      .first;
  final partes = limpio.split('.');
  if (partes.isEmpty || partes.length > 3) return null;

  final numeros = <int>[];
  for (final parte in partes) {
    final n = int.tryParse(parte);
    if (n == null || n < 0) return null;
    numeros.add(n);
  }
  while (numeros.length < 3) {
    numeros.add(0);
  }
  return numeros;
}

/// true si [candidata] es estrictamente más nueva que [instalada].
/// Si alguna de las dos no se puede interpretar, devuelve false (no bloquear por error).
bool esVersionMasNueva(String candidata, String instalada) {
  final a = parsearVersion(candidata);
  final b = parsearVersion(instalada);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}
