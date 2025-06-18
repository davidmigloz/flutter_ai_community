// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

class DartanticProvider extends LlmProvider with ChangeNotifier {
  DartanticProvider(dartantic.Agent agent,
      {Iterable<ChatMessage> history = const []})
      : _agent = agent,
        _history = history.toList();

  final dartantic.Agent _agent;
  final List<ChatMessage> _history;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) =>
      _generateStream(
        prompt: prompt,
        attachments: attachments,
      );

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    final response = _generateStream(
      prompt: prompt,
      attachments: attachments,
    );

    yield* response.map((chunk) {
      llmMessage.append(chunk);
      return chunk;
    });

    // notify listeners that the history has changed when response is complete
    notifyListeners();
  }

  Stream<String> _generateStream({
    required String prompt,
    required Iterable<Attachment> attachments,
  }) =>
      _agent
          .runStream(prompt,
              messages: _dartanticMessagesFrom(_history),
              attachments: _dartanticPartsFrom(attachments))
          .map((response) => response.output)
          .where((t) => t.isNotEmpty);

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  Iterable<dartantic.Message> _dartanticMessagesFrom(
          List<ChatMessage> history) =>
      [
        for (final message in history)
          dartantic.Message(
            role: _dartanticRoleFrom(message.origin),
            parts: [
              // Always include text part to ensure content is never empty
              dartantic.TextPart(message.text ?? ''),
              ..._dartanticPartsFrom(message.attachments)
            ],
          ),
      ];

  Iterable<dartantic.Part> _dartanticPartsFrom(
          Iterable<Attachment> attachments) =>
      [
        for (final attachment in attachments)
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

  dartantic.MessageRole _dartanticRoleFrom(MessageOrigin origin) =>
      switch (origin) {
        MessageOrigin.user => dartantic.MessageRole.user,
        MessageOrigin.llm => dartantic.MessageRole.model,
      };
}
