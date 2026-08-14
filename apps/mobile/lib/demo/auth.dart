import 'package:flutter/foundation.dart';

class DemoUser {
  const DemoUser({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
  });

  final String email;
  final String password;
  final String name;
  final String role;
}

const demoUsers = [
  DemoUser(
    email: 'felipe@gssolucoestec.com.br',
    password: 'demonstracao',
    name: 'Felipe Souza',
    role: 'Técnico',
  ),
  DemoUser(
    email: 'cleber@gssolucoestec.com.br',
    password: 'demonstracao',
    name: 'Cleber Guimarães',
    role: 'Responsável técnico',
  ),
  DemoUser(
    email: 'andre@gssolucoestec.com.br',
    password: 'demonstracao',
    name: 'Andre Nascimento',
    role: 'Técnico',
  ),
];

class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final instance = AuthSession._();

  DemoUser? user;

  bool get isSignedIn => user != null;

  String? signIn(String email, String password) {
    final normalized = email.trim().toLowerCase();
    final match = demoUsers.where((item) => item.email == normalized).firstOrNull;
    if (match == null || match.password != password) {
      return 'Usuário ou senha inválidos';
    }
    user = match;
    notifyListeners();
    return null;
  }

  void signOut() {
    user = null;
    notifyListeners();
  }
}
