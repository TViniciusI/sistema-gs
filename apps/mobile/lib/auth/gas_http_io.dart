import 'package:http/http.dart' as http;

Future<String> gasGet(
  Uri uri, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final response = await http.get(uri).timeout(timeout);
  return response.body;
}

Future<String> gasPost(
  Uri uri,
  String jsonBody, {
  Duration timeout = const Duration(seconds: 25),
  bool allowOpaque = false,
}) async {
  final response = await http
      .post(
        uri,
        headers: const {'Content-Type': 'text/plain;charset=utf-8'},
        body: jsonBody,
      )
      .timeout(timeout);
  return response.body;
}
