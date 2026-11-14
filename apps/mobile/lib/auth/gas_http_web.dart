import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

int _jsonpSeq = 0;

Future<String> gasGet(
  Uri uri, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final name = 'gsCampoCb${++_jsonpSeq}${DateTime.now().microsecondsSinceEpoch}';
  final completer = Completer<String>();
  final script = web.HTMLScriptElement()..async = true;

  void cleanup() {
    script.remove();
    globalContext.delete(name.toJS);
  }

  globalContext.setProperty(
    name.toJS,
    ((JSAny? data) {
      try {
        if (!completer.isCompleted) {
          completer.complete(jsonEncode(data?.dartify()));
        }
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      } finally {
        cleanup();
      }
    }).toJS,
  );

  script.addEventListener(
    'error',
    ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Não foi possível falar com a planilha.'),
        );
      }
      cleanup();
    }).toJS,
  );

  final params = Map<String, String>.from(uri.queryParameters);
  params['callback'] = name;
  script.src = uri.replace(queryParameters: params).toString();
  web.document.head?.append(script);

  return completer.future.timeout(timeout);
}

Future<String> gasPost(
  Uri uri,
  String jsonBody, {
  Duration timeout = const Duration(seconds: 25),
  bool allowOpaque = false,
}) {
  return _gasPost(
    uri,
    jsonBody,
    allowOpaque: allowOpaque,
  ).timeout(timeout);
}

Future<String> _gasPost(
  Uri uri,
  String jsonBody, {
  bool allowOpaque = false,
}) async {
  web.Headers headersOf() {
    final headers = web.Headers();
    headers.set('Content-Type', 'text/plain;charset=utf-8');
    return headers;
  }

  try {
    final res = await web.window
        .fetch(
          uri.toString().toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonBody.toJS,
            headers: headersOf(),
            mode: 'cors',
          ),
        )
        .toDart;
    final text = (await res.text().toDart).toDart;
    if (text.trim().isNotEmpty && !text.trimLeft().startsWith('<')) {
      return text;
    }
  } catch (_) {}
  if (!allowOpaque) {
    throw Exception(
      'A planilha não confirmou o envio com o PDF anexo.',
    );
  }
  try {
    await web.window
        .fetch(
          uri.toString().toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonBody.toJS,
            headers: headersOf(),
            mode: 'no-cors',
          ),
        )
        .toDart;
  } catch (error) {
    throw Exception('Não foi possível enviar o e-mail. $error');
  }
  return jsonEncode({'ok': true, 'opaque': true});
}
