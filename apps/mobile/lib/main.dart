import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/auth/login_page.dart';
import 'package:gs_mobile/features/home/home_page.dart';

void main() {
  runApp(const GsApp());
}

class GsApp extends StatelessWidget {
  const GsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GS Campo',
      debugShowCheckedModeBanner: false,
      theme: GsTheme.data,
      home: ListenableBuilder(
        listenable: AuthSession.instance,
        builder: (context, _) {
          if (AuthSession.instance.isSignedIn) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
