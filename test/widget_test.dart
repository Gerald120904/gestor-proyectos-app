import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_proyectos_app/main.dart';

void main() {
  testWidgets('La app carga la pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(const GestorProyectosApp());

    expect(find.text('Gestor de Proyectos'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}