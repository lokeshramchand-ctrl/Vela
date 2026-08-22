import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned response for one request, queued by [FakeHttpClientAdapter.queue].
class FakeResponse {
  const FakeResponse({required this.statusCode, this.body});

  final int statusCode;
  final Object? body;
}

/// A scriptable [HttpClientAdapter]: tests queue exact
/// "METHOD path" -> response sequences (e.g. register, then the login it
/// triggers, then the /users/me it triggers) instead of hitting a real
/// server. Each call to [queue] appends to that key's FIFO queue, so a
/// path hit twice in one flow (e.g. two /users/me calls) can return two
/// different responses in order.
class FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, List<FakeResponse>> _queued = {};
  final List<RequestOptions> requests = [];

  void queue(String method, String path, FakeResponse response) {
    _queued.putIfAbsent(_key(method, path), () => []).add(response);
  }

  String _key(String method, String path) => '${method.toUpperCase()} $path';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = _key(options.method, options.path);
    final queue = _queued[key];
    if (queue == null || queue.isEmpty) {
      throw StateError('FakeHttpClientAdapter: no response queued for $key');
    }
    final response = queue.removeAt(0);
    final bodyText = response.body == null ? '' : jsonEncode(response.body);
    return ResponseBody.fromString(
      bodyText,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
