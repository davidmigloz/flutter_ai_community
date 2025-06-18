// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

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
  }) async* {
    final dartanticMessages = _dartanticMessagesFrom(_history).toList();
    assert(dartanticMessages.length == _history.length,
        'Dartantic message count (${dartanticMessages.length}) must match chat message count (${_history.length})');

    yield* _agent
        .runStream(prompt, messages: dartanticMessages)
        .map((response) => response.output)
        .where((t) => t.isNotEmpty);
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  Iterable<dartantic.Message> _dartanticMessagesFrom(
      List<ChatMessage> history) sync* {
    for (final message in history) {
      final content = <dartantic.Part>[
        // Always include text part, even if empty, to ensure content is never
        // empty, e.g. when we create an empty ChatMessage.llm() above.
        dartantic.TextPart(message.text ?? ''),
        for (final attachment in message.attachments)
          switch (attachment) {
            ImageFileAttachment() => dartantic.MediaPart(
                contentType: attachment.mimeType,
                url: 'data:${attachment.mimeType};'
                    'base64,${base64Encode(attachment.bytes)}',
              ),
            FileAttachment() => dartantic.MediaPart(
                contentType: attachment.mimeType,
                url: 'data:${attachment.mimeType};'
                    'base64,${base64Encode(attachment.bytes)}',
              ),
            LinkAttachment() => dartantic.TextPart(
                'Link: ${attachment.url}',
              ),
          },
      ];

      yield switch (message.origin) {
        MessageOrigin.user => dartantic.Message.user(content),
        MessageOrigin.llm => dartantic.Message.model(content),
      };
    }
  }
}
