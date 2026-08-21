import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logto_dart_sdk/logto_client.dart';
import 'package:logto_dart_sdk/logto_dart_sdk.dart';
import 'package:nock/nock.dart';

import 'mocks/mock_storage.dart';
import 'mocks/responses.dart';

const _webAuthChannel = MethodChannel('flutter_web_auth_2');
const _logtoOrigin = 'https://logto.test';
const _redirectUri = 'io.logto.test://callback';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    nock.init;
  });

  setUp(nock.cleanAll);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_webAuthChannel, null);
  });

  tearDownAll(() {
    nock.cleanAll();
  });

  test('Init Logto Instance', () {
    const String appId = 'foo';
    const String endpoint = 'foo@siverhand.io';

    const config = LogtoConfig(appId: 'foo', endpoint: 'foo@siverhand.io');

    final logto = LogtoClient(
      config: config,
      storageProvider: MockStorageStrategy(),
    );

    expect(logto.config.appId, appId);
    expect(logto.config.endpoint, endpoint);
  });

  test('Sign in keeps the Android authentication activity in history',
      () async {
    Uri? discoveryUri;
    final httpClient = MockClient((request) async {
      discoveryUri = request.url;
      return http.Response(
        jsonEncode(mockOidcConfigResponse),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    });

    MethodCall? authenticationCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_webAuthChannel, (call) async {
      authenticationCall = call;
      throw PlatformException(code: 'CANCELED');
    });

    final logto = LogtoClient(
      config: const LogtoConfig(appId: 'foo', endpoint: _logtoOrigin),
      storageProvider: MockStorageStrategy(),
      httpClient: httpClient,
    );

    await expectLater(
      logto.signIn(_redirectUri),
      throwsA(
        isA<PlatformException>()
            .having((exception) => exception.code, 'code', 'CANCELED'),
      ),
    );

    expect(
      discoveryUri,
      Uri.parse('$_logtoOrigin/oidc/.well-known/openid-configuration'),
    );
    expect(authenticationCall?.method, 'authenticate');

    final arguments = authenticationCall?.arguments as Map<Object?, Object?>;
    final options = arguments['options'] as Map<Object?, Object?>;
    expect(options['preferEphemeral'], isTrue);
    expect(options['intentFlags'], 0);
  });
}
