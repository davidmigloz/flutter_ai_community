import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_providers/flutter_ai_providers.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

void main() => runApp(_App());

class _App extends StatelessWidget {
  static const title = 'Example: Dartantic AI';

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: title, home: _ChatPage());
}

class _ChatPage extends StatefulWidget {
  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final agent = Agent('openai', tools: [
    Tool(
        name: 'local_time',
        description: 'Returns the current local time.',
        onCall: (args) async => {'result': DateTime.now().toIso8601String()})
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(_App.title)),
      body: Column(
        children: [
          Expanded(child: LlmChatView(provider: DartanticProvider(agent))),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: Text(agent.model)),
          )
        ],
      ),
    );
  }
}
