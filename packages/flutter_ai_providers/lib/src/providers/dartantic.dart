import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as toolkit;

/// An [LlmProvider] that uses the `dartantic_ai` package.
///
/// # Implementation notes
/// This implementation keeps two copies of the conversation history:
/// - The [history] getter/setter provides the history as a list of
///   [toolkit.ChatMessage] objects, as required by the [LlmProvider] interface.
///   This is really just a cache of the [_messages] field, post conversion.
/// - The internal [_messages] field holds the history as a list of
///   [ChatMessage] objects. It's the real history.
///
/// This dual-representation is necessary because `flutter_ai_toolkit`'s
/// [toolkit.ChatMessage] does not support tool usage information, which is
/// required for multi-turn conversations with the `dartantic_ai` agent. By
/// managing both, this provider can participate in `flutter_ai_toolkit`-based
/// UIs while still correctly handling tool-based conversations with the
/// underlying LLM.
///
/// The consequence of that is that when history is set on this provider, e.g.
/// when the user edits a message, then the tool parts are dropped. Something
/// like this fix is need to really fix the problem:
/// https://github.com/flutter/ai/issues/130
class DartanticProvider extends toolkit.LlmProvider with ChangeNotifier {
  DartanticProvider(
    dartantic.Agent agent, {
    Iterable<toolkit.ChatMessage> history = const [],
  })  : _agent = agent,
        _messages = history.dartanticMessages.toList();

  final dartantic.Agent _agent;
  final List<ChatMessage> _messages;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<toolkit.Attachment> attachments = const [],
  }) =>
      _generateStream(
        prompt: prompt,
        attachments: attachments,
      ).map((response) => response.output as String);

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<toolkit.Attachment> attachments = const [],
  }) async* {
    final userMessage = toolkit.ChatMessage.user(prompt, attachments);
    final llmMessage = toolkit.ChatMessage.llm();
    history.addAll([userMessage, llmMessage]); // make sure we have a history

    var messages = <ChatMessage>[];
    await for (final response in _generateStream(
      prompt: prompt,
      attachments: attachments,
    )) {
      messages = response.messages;
      final output = response.output as String;
      if (output.isNotEmpty) llmMessage.append(output);
      yield output;
    }

    // notify listeners that the history has changed when response is complete
    // _historyCache = null; // no need to clear the cache, we've updated it
    _messages.reset(messages);
    notifyListeners();
  }

  Stream<ChatResult> _generateStream({
    required String prompt,
    required Iterable<toolkit.Attachment> attachments,
  }) =>
      _agent.sendStream(
        prompt,
        history: _messages,
        attachments: attachments.dartanticParts.toList(),
      );

  List<toolkit.ChatMessage>? _historyCache;

  @override
  List<toolkit.ChatMessage> get history =>
      _historyCache ??= _messages.chatMessages.toList();

  @override
  set history(Iterable<toolkit.ChatMessage> history) {
    if (_messages.any((m) => m.parts.any((p) => p is ToolPart))) {
      debugPrint('WARNING: setting the `history` drops tool parts!');
    }

    _historyCache = null;
    _messages.reset(history.dartanticMessages);
    notifyListeners();
  }

  Iterable<ChatMessage> get messages => _messages;

  set messages(Iterable<ChatMessage> messages) {
    _historyCache = null;
    _messages.reset(messages);
    notifyListeners();
  }
}

extension on List {
  void reset(Iterable items) {
    clear();
    addAll(items);
  }
}

extension on toolkit.MessageOrigin {
  ChatMessageRole get dartanticRole => switch (this) {
        toolkit.MessageOrigin.user => ChatMessageRole.user,
        toolkit.MessageOrigin.llm => ChatMessageRole.model,
      };
}

extension on ChatMessageRole {
  toolkit.MessageOrigin get messageOrigin => switch (this) {
        ChatMessageRole.user => toolkit.MessageOrigin.user,
        ChatMessageRole.model => toolkit.MessageOrigin.llm,
        ChatMessageRole.system =>
          throw Exception('System messages are not supported'),
      };
}

extension on Iterable<toolkit.ChatMessage> {
  Iterable<ChatMessage> get dartanticMessages => [
        for (final message in this)
          ChatMessage(
            role: message.origin.dartanticRole,
            parts: [
              // consolidate text into a single part
              TextPart(message.text ?? ''),
              ...message.attachments.dartanticParts,
            ],
          ),
      ];
}

extension on Iterable<toolkit.Attachment> {
  Iterable<Part> get dartanticParts => [
        for (final attachment in this)
          switch (attachment) {
            toolkit.ImageFileAttachment() => DataPart(
                attachment.bytes,
                mimeType: attachment.mimeType,
              ),
            toolkit.FileAttachment() => DataPart(
                attachment.bytes,
                mimeType: attachment.mimeType,
              ),
            toolkit.LinkAttachment() => LinkPart(attachment.url),
          },
      ];
}

extension on Iterable<ChatMessage> {
  Iterable<toolkit.ChatMessage> get chatMessages => [
        for (final message in this)
          toolkit.ChatMessage(
            text: message.text,
            origin: message.role.messageOrigin,
            attachments: message.parts.attachments,
          ),
      ];
}

extension on Iterable<Part> {
  Iterable<toolkit.Attachment> get attachments sync* {
    for (final part in where(
      (part) => part is! TextPart && part is! ToolPart,
    )) {
      switch (part) {
        case DataPart():
          yield toolkit.FileAttachment(
            bytes: part.bytes,
            mimeType: part.mimeType,
            name: _nameFromMimeType(part.mimeType),
          );
        case LinkPart():
          yield toolkit.LinkAttachment(
            url: part.url,
            name: _nameFromMimeType(part.mimeType ?? ''),
          );

        case TextPart():
        case ToolPart():
          assert(false, 'Do not pass text or tool parts here!');
      }
    }
  }
}

String _nameFromMimeType(String mimeType) => mimeType.startsWith('image/')
    ? 'image.${mimeType.split('/').last}'
    : 'file.${mimeType.split('/').last}';
