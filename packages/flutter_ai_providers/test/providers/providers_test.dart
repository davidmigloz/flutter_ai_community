import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ai_providers/flutter_ai_providers.dart';

void main() {
  void runProviderTests(LlmProvider Function() providerFactory) {
    group('Provider tests', () {
      late LlmProvider provider;

      setUp(() {
        provider = providerFactory();
      });

      tearDown(() {
        (provider as ChangeNotifier).dispose();
      });

      test('generates stream', () async {
        final stream = provider.generateStream(
          'List the numbers from 1 to 5 in order. '
          'Output ONLY the numbers in one line without any spaces or commas.',
        );
        var output = (await stream.toList()).join();
        expect(output, contains('12345'));
      });

      test('sends message stream and updates history', () async {
        final stream = provider.sendMessageStream('Hello');
        expect(await stream.toList(), isNotEmpty);
        expect(provider.history.length, 2);
        expect(provider.history.first.text, 'Hello');
        expect(provider.history.last.text, isNotEmpty);
      });

      test('handles image attachment', () async {
        final imageBytes =
            await File('./test/assets/flutter_logo.png').readAsBytes();
        final imageAttachment = ImageFileAttachment(
          name: 'flutter_logo.png',
          mimeType: 'image/png',
          bytes: imageBytes,
        );

        final stream = provider.generateStream(
          "Which framework is this logo from?",
          attachments: [imageAttachment],
        );
        var output = (await stream.toList()).join();
        expect(output, contains('Flutter'));
      });
    });
  }

  group('OpenAIProvider', () {
    runProviderTests(
      () => OpenAIProvider(
        apiKey: Platform.environment['OPENAI_API_KEY']!,
        model: 'gpt-5-mini',
      ),
    );
  });

  group('AnthropicProvider', () {
    runProviderTests(
      () => AnthropicProvider(
        apiKey: Platform.environment['ANTHROPIC_API_KEY']!,
        model: 'claude-3-5-sonnet-latest',
      ),
    );
  });

  group('OllamaProvider', skip: Platform.environment.containsKey('CI'), () {
    runProviderTests(
      () => OllamaProvider(model: 'llama3.2-vision'),
    );
  });

  group('OpenwebuiProvider', skip: Platform.environment.containsKey('CI'), () {
    runProviderTests(
      () => OpenWebUIProvider(
          baseUrl: "http://192.168.178.21:3000/api",
          apiKey:
              "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjJkYWYyMWUzLWFkZWQtNDc4OS05ZDNiLTQ2NDQzNDk2ODFjMyJ9.SMvMsAioNCMZF8hgCUvZHBGgfwZCLJEqxPwXYIoAO4w",
          model: 'llama3.2-vision:11b'),
    );
  });
}
