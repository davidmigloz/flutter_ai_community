import 'package:flutter/material.dart';
import 'package:flutter_ai_providers/flutter_ai_providers.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  static const title = 'Example: Anthropic';

  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: title, home: ChatPage());
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(App.title)),
        body: LlmChatView(
          provider: AnthropicProvider(
            apiKey: 'your-api-key',
            model: 'claude-3-sonnet-20240229',
          ),
        ),
      );
}
