import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/config.dart';
import '../models/request.dart';
import '../models/response.dart';
import 'adapter.dart';

class HttpPackageAdapter extends CoffeeTransportAdapter {
  final CoffeeHttpConfig _config;

  HttpPackageAdapter(this._config);
  String? _encodeJsonBody(Object? jsonBody) {
    if (jsonBody == null) return null;
    if (jsonBody is String) return jsonBody;
    return jsonEncode(jsonBody);
  }

  @override
  Future<CoffeeRawResponse> send(
    CoffeeRequest request, {
    required Map<String, String> headers,
  }) async {
    Uri uri = _config.baseUrl.build(request.path, query: request.query);

    http.Response res;

    switch (request.method) {
      case CoffeeHttpMethod.get:
        res = await http
            .get(uri, headers: headers)
            .timeout(_config.timeouts.receiveTimeout);

      case CoffeeHttpMethod.post:
        res = await http
            .post(
              uri,
              headers: headers,
              body: _encodeJsonBody(request.jsonBody),
            )
            .timeout(_config.timeouts.receiveTimeout);

      case CoffeeHttpMethod.put:
        res = await http
            .put(uri, headers: headers, body: _encodeJsonBody(request.jsonBody))
            .timeout(_config.timeouts.receiveTimeout);

      case CoffeeHttpMethod.patch:
        res = await http
            .patch(
              uri,
              headers: headers,
              body: _encodeJsonBody(request.jsonBody),
            )
            .timeout(_config.timeouts.receiveTimeout);

      case CoffeeHttpMethod.delete:
        res = await http
            .delete(
              uri,
              headers: headers,
              body: _encodeJsonBody(request.jsonBody),
            )
            .timeout(_config.timeouts.receiveTimeout);
    }

    return CoffeeRawResponse(
      statusCode: res.statusCode,
      headers: Map<String, String>.from(res.headers),
      body: res.body, // String
      duration: Duration.zero, // measured in CoffeeHttp.request()
    );
  }
}
