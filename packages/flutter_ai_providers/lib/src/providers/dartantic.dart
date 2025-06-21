// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// An [LlmProvider] that uses the `dartantic_ai` package.
///
/// # Implementation notes
/// This implementation keeps two copies of the conversation history:
/// - The [history] getter/setter provides the history as a list of
///   [ChatMessage] objects, as required by the [LlmProvider] interface. This
///   is really just a cache of the [_messages] field, post conversion.
/// - The internal [_messages] field holds the history as a list of
///   [dartantic.Message] objects. It's the real history.
///
/// This dual-representation is necessary because `flutter_ai_toolkit`'s
/// [ChatMessage] does not support tool usage information, which is required
/// for multi-turn conversations with the `dartantic_ai` agent. By managing
/// both, this provider can participate in `flutter_ai_toolkit`-based UIs while
/// still correctly handling tool-based conversations with the underlying LLM.
///
/// The consequence of that is that when history is set on this provider, e.g.
/// when the user edits a message, then the tool parts are dropped. Something
/// like this fix is need to really fix the problem:
/// https://github.com/flutter/ai/issues/130
class DartanticProvider extends LlmProvider with ChangeNotifier {
  DartanticProvider(
    dartantic.Agent agent, {
    Iterable<ChatMessage> history = const [],
  })  : _agent = agent,
        _messages = history.dartanticMessages.toList();

  final dartantic.Agent _agent;
  final List<dartantic.Message> _messages;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) =>
      _generateStream(
        prompt: prompt,
        attachments: attachments,
      ).map((response) => response.output);

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    history.addAll([userMessage, llmMessage]); // make sure we have a history

    var messages = <dartantic.Message>[];
    await for (final response in _generateStream(
      prompt: prompt,
      attachments: attachments,
    )) {
      messages = response.messages;
      if (response.output.isNotEmpty) llmMessage.append(response.output);
      yield response.output;
    }

    // notify listeners that the history has changed when response is complete
    // _historyCache = null; // no need to clear the cache, we've updated it
    _messages.reset(messages);
    notifyListeners();
  }

  Stream<dartantic.AgentResponse> _generateStream({
    required String prompt,
    required Iterable<Attachment> attachments,
  }) =>
      _agent.runStream(
        prompt,
        messages: _messages,
        attachments: attachments.dartanticParts,
      );

  List<ChatMessage>? _historyCache;

  @override
  List<ChatMessage> get history =>
      _historyCache ??= _messages.chatMessages.toList();

  @override
  set history(Iterable<ChatMessage> history) {
    if (_messages.any((m) => m.parts.any((p) => p is dartantic.ToolPart))) {
      debugPrint('WARNING: setting the `history` drops tool parts!');
    }

    _historyCache = null;
    _messages.reset(history.dartanticMessages);
    notifyListeners();
  }

  Iterable<dartantic.Message> get messages => _messages;

  set messages(Iterable<dartantic.Message> messages) {
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

extension on MessageOrigin {
  dartantic.MessageRole get dartanticRole => switch (this) {
        MessageOrigin.user => dartantic.MessageRole.user,
        MessageOrigin.llm => dartantic.MessageRole.model,
      };
}

extension on dartantic.MessageRole {
  MessageOrigin get messageOrigin => switch (this) {
        dartantic.MessageRole.user => MessageOrigin.user,
        dartantic.MessageRole.model => MessageOrigin.llm,
        dartantic.MessageRole.system =>
          throw Exception('System messages are not supported'),
      };
}

extension on Iterable<ChatMessage> {
  Iterable<dartantic.Message> get dartanticMessages => [
        for (final message in this)
          dartantic.Message(
            role: message.origin.dartanticRole,
            parts: [
              // consolidate text into a single part
              dartantic.TextPart(message.text ?? ''),
              ...message.attachments.dartanticParts,
            ],
          ),
      ];
}

extension on Iterable<Attachment> {
  Iterable<dartantic.Part> get dartanticParts => [
        for (final attachment in this)
          switch (attachment) {
            ImageFileAttachment() => dartantic.DataPart(
                attachment.bytes,
                mimeType: attachment.mimeType,
              ),
            FileAttachment() => dartantic.DataPart(
                attachment.bytes,
                mimeType: attachment.mimeType,
              ),
            LinkAttachment() => dartantic.LinkPart(attachment.url),
          },
      ];
}

extension on Iterable<dartantic.Message> {
  Iterable<ChatMessage> get chatMessages => [
        for (final message in this)
          ChatMessage(
            text: message.text,
            origin: message.role.messageOrigin,
            attachments: message.parts.attachments,
          ),
      ];
}

extension on Iterable<dartantic.Part> {
  Iterable<Attachment> get attachments sync* {
    for (final part in where(
      (part) => part is! dartantic.TextPart && part is! dartantic.ToolPart,
    )) {
      switch (part) {
        case dartantic.DataPart():
          yield FileAttachment(
            bytes: part.bytes,
            mimeType: part.mimeType,
            name: _nameFromMimeType(part.mimeType),
          );
        case dartantic.LinkPart():
          yield LinkAttachment(
            url: part.url,
            name: _nameFromMimeType(part.mimeType),
          );

        case dartantic.TextPart():
        case dartantic.ToolPart():
          assert(false, 'Do not pass text or tool parts here!');
      }
    }
  }
}

String _nameFromMimeType(String mimeType) => mimeType.startsWith('image/')
    ? 'image.${mimeType.split('/').last}'
    : 'file.${mimeType.split('/').last}';
