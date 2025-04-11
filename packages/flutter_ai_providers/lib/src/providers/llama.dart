import 'package:flutter/foundation.dart';
import 'package:llama_sdk/llama_sdk.dart'
    if (dart.library.html) 'package:llama_sdk/llama_sdk.web.dart'; // Use mock implementation for web
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// A provider for the Llama.cpp models.
///
/// This provider implements the [LlmProvider] interface to integrate Llama's
/// locally hosted models into the chat interface.
class LlamaProvider extends LlmProvider with ChangeNotifier {
  /// Creates a llama provider instance.
  ///
  /// The [modelPath] parameter specifies the path to the Llama model file.
  ///
  /// The [modelOptions] parameter is a map of options to configure the model.
  /// For example, you can specify options like `n_ctx` or `n_batch`.
  LlamaProvider({
    required String modelPath,
    Map<String, dynamic> modelOptions = const {},
  })  : _client = Llama(LlamaController.fromMap({
          'model_path': modelPath,
          'greedy': true,
          ...modelOptions,
        })),
        _history = [];

  final Llama _client;
  final List<ChatMessage> _history;

  @override
  Stream<String> generateStream(String prompt,
      {Iterable<Attachment> attachments = const []}) async* {
    final messages = _mapToLlamaMessages([
      ChatMessage.user(prompt, attachments),
    ]);

    yield* _generateStream(messages);
  }

  @override
  Stream<String> sendMessageStream(String prompt,
      {Iterable<Attachment> attachments = const []}) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    _history.add(userMessage);

    final messages = _mapToLlamaMessages(_history);

    final stream = _generateStream(messages);

    final llmMessage = ChatMessage.llm();
    _history.add(llmMessage);

    yield* stream.map((chunk) {
      llmMessage.append(chunk);
      return chunk;
    });

    notifyListeners();
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  void dispose() {
    _client.stop();
    _client.reload();
    super.dispose();
  }

  /// Stops the current generation.
  /// This is useful for stopping a long-running generation process.
  /// Call this method when you want to cancel the current operation.
  void stop() => _client.stop();

  /// Reloads the model.
  void reload() => _client.reload();

  Stream<String> _generateStream(List<LlamaMessage> messages) async* {
    _client.stop();
    _client.reload();

    final stream = _client.prompt(messages);

    yield* stream;
  }

  List<LlamaMessage> _mapToLlamaMessages(Iterable<ChatMessage> messages) {
    return messages.map((message) {
      return LlamaMessage.withRole(
        role: message.origin == MessageOrigin.user ? 'user' : 'assistant',
        content: message.text ?? '',
      );
    }).toList();
  }
}
