import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:downlink/src/native_host/native_host.dart';
import 'package:downlink/src/native_host/app_client.dart';
import 'package:downlink/src/native_host/native_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native message framing round trips JSON', () {
    final encoded = encodeNativeMessage({
      'id': '1',
      'command': 'ping',
      'success': true,
    });
    final decoder = NativeMessageDecoder();
    final messages = decoder.add(encoded);

    expect(messages, hasLength(1));
    expect(decodeJsonMessage(messages.single), {
      'id': '1',
      'command': 'ping',
      'success': true,
    });
  });

  test('native message decoder rejects oversized messages', () {
    final lengthPrefix = List<int>.filled(4, 0);
    final oversized = nativeMessageMaxSize + 1;
    lengthPrefix[0] = oversized & 0xff;
    lengthPrefix[1] = (oversized >> 8) & 0xff;
    lengthPrefix[2] = (oversized >> 16) & 0xff;
    lengthPrefix[3] = (oversized >> 24) & 0xff;

    expect(
      () => NativeMessageDecoder().add(lengthPrefix),
      throwsA(isA<NativeMessageException>()),
    );
  });

  test('native host rejects invalid JSON', () async {
    final outputs = <List<int>>[];
    final badJson = <int>[4, 0, 0, 0, ...utf8.encode('nope')];

    await NativeHost(
      client: _FakeClient(),
    ).run(Stream<List<int>>.value(badJson), outputs.add);
    final response = decodeJsonMessage(
      NativeMessageDecoder().add(outputs.single).single,
    );

    expect(response['success'], false);
    expect(response['error'], 'invalid_json');
  });

  test('native host validates supported commands', () async {
    final outputs = <List<int>>[];

    await NativeHost(client: _FakeClient()).run(
      Stream<List<int>>.value(encodeNativeMessage({'command': 'bogus'})),
      outputs.add,
    );
    final response = decodeJsonMessage(
      NativeMessageDecoder().add(outputs.single).single,
    );

    expect(response['success'], false);
    expect(response['error'], 'invalid_request');
  });

  test('native host reports app unavailable', () async {
    final response = await _hostResponse(
      client: _FakeClient(socketException: true),
      message: {'command': 'show'},
    );

    expect(response['success'], false);
    expect(response['error'], 'app_unavailable');
  });

  test('native host reports app timeout', () async {
    final response = await _hostResponse(
      client: _FakeClient(timeout: true),
      message: {'command': 'show'},
    );

    expect(response['success'], false);
    expect(response['error'], 'timeout');
  });
}

class _FakeClient implements NativeHostAppConnection {
  _FakeClient({this.socketException = false, this.timeout = false});

  final bool socketException;
  final bool timeout;

  @override
  Future<Map<String, Object?>> ping(Map<String, Object?> command) async {
    return {'command': 'ping', 'success': true};
  }

  @override
  Future<Map<String, Object?>> send(Map<String, Object?> command) async {
    if (socketException) throw const SocketException('unavailable');
    if (timeout) throw TimeoutException('timed out');
    return {'command': command['command'], 'success': true};
  }
}

Future<Map<String, Object?>> _hostResponse({
  required NativeHostAppConnection client,
  required Map<String, Object?> message,
}) async {
  final outputs = <List<int>>[];
  await NativeHost(
    client: client,
  ).run(Stream<List<int>>.value(encodeNativeMessage(message)), outputs.add);
  return decodeJsonMessage(NativeMessageDecoder().add(outputs.single).single);
}
