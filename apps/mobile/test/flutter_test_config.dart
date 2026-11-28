import 'dart:async';
import 'dart:io';

import 'package:gs_mobile/auth/account_api.dart';

/// A URL da planilha é a de produção por padrão: um teste com rede gravou
/// um cliente falso na planilha real. Testes só falam com 127.0.0.1.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AccountApi.useRemote = false;
  HttpOverrides.global = _LoopbackOnly();
  await testMain();
}

class _LoopbackOnly extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      final host = uri.host;
      if (host != '127.0.0.1' && host != 'localhost') {
        throw SocketException('Teste sem rede: bloqueado acesso a $host');
      }
      return Socket.startConnect(host, uri.port);
    };
    return client;
  }
}
