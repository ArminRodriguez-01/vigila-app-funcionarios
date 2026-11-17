import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/auth_config.dart';
import 'package:vigila_funcionarios/core/auth/http_auth_repository.dart';

void main() {
  test('el mock nunca se activa en release aunque se haya solicitado', () {
    expect(resolverUsarMock(solicitado: true, esRelease: true), isFalse);
  });

  test('el mock se activa solo si se solicita y no es release', () {
    expect(resolverUsarMock(solicitado: true, esRelease: false), isTrue);
    expect(resolverUsarMock(solicitado: false, esRelease: false), isFalse);
    expect(resolverUsarMock(solicitado: false, esRelease: true), isFalse);
  });

  test('sin --dart-define=USAR_MOCK_AUTH el mock está apagado', () {
    expect(AuthConfig.usarMock, isFalse);
  });

  test('crearAuthRepository usa el backend real cuando el mock está apagado', () {
    expect(crearAuthRepository(), isA<HttpAuthRepository>());
  });
}
