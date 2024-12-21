// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:http/http.dart' as http;

/// Internal open-webui json encoder / decoder
extension _OwuiMessage on ChatMessage {
  /// Converts the [ChatMessage] instance to a JSON object.
  Map<String, dynamic> toOwuiJson() => {
    'role': origin == MessageOrigin.user ? 'user' : 'assistant',
    'content': text,
    'files': [
      /// ... Figure out how to handle attachments
    ]
  };

  /// Creates an instance of [ChatMessage] from a JSON object.
  static fromOwuiJson(Map<String, dynamic> json) {
    return ChatMessage(
      origin: json['role'] == 'user' ? MessageOrigin.user : MessageOrigin.llm,
      text: json['delta']?['content'],
      attachments: [],
    );
  }
}

/// Internal open-webui json encoder / decoder
/// Encode a request to the open-webui API.
class _OwuiChatRequest {
  final String model;
  final List<ChatMessage> messages;

  /// Creates an instance of [_OwuiChatRequest].
  ///
  /// [model] is the model to be used for the chat.
  /// [messages] is the list of messages in the chat history.
  _OwuiChatRequest({required this.model, required this.messages});

  /// Converts the [_OwuiChatRequest] instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'model': model,
    'stream': true,
    'messages': messages.map((message) => message.toOwuiJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Internal open-webui json encoder / decoder
/// Decode a chat response from the open-webui API.
class _OwuiChatResponse {
  final List<_OwuiChatResponseChoice> choices;

  /// Creates an instance of [_OwuiChatResponse].
  ///
  /// [choices] is the list of choices in the response.
  _OwuiChatResponse({required this.choices});

  /// Creates an instance of [_OwuiChatResponse] from a JSON object.
  factory _OwuiChatResponse.fromJson(Map<String, dynamic> json) {
    return _OwuiChatResponse(
      choices: (json['choices'] as List).map((choice) => _OwuiChatResponseChoice.fromJson(choice)).toList(),
    );
  }

  factory _OwuiChatResponse.fromJsonString(String jsonString) {
    return _OwuiChatResponse.fromJson(jsonDecode(jsonString));
  }
}

/// Internal open-webui json encoder / decoder
/// Decoder for the choice part of [_OwuiChatResponse].
class _OwuiChatResponseChoice {
  final ChatMessage message;

  /// Creates an instance of [_OwuiChatResponseChoice].
  ///
  /// [message] is the message in the choice.
  _OwuiChatResponseChoice({required this.message});

  /// Creates an instance of [_OwuiChatResponseChoice] from a JSON object.
  factory _OwuiChatResponseChoice.fromJson(Map<String, dynamic> json) {
    return _OwuiChatResponseChoice(
      message: _OwuiMessage.fromOwuiJson(json),
    );
  }
}


/// A provider for [open-webui](https://openwebui.com/)
/// Use open-webui as unified chat provider.
class OpenwebuiProvider extends LlmProvider with ChangeNotifier {
  /// Creates an [OpenwebuiProvider] instance with an optional chat history.
  ///
  /// The [history] parameter is an optional iterable of [ChatMessage] objects
  /// representing the chat history
  /// The [model] parameter is the ai model to be used for the chat.
  /// The [host] parameter is the host of the open-webui server.
  /// For example port 3000 on localhost use 'http://localhost:3000'
  /// The [apiKey] parameter is the API key for the open-webui server.
  /// See the [docs](https://docs.openwebui.com/) for more information.
  /// Example:
  /// ``` dart
  /// LlmChatView(
  ///   provider: OpenwebuiProvider(
  ///     host: 'http://127.0.0.1:3000',
  ///     model: 'llama3.1:latest',
  ///     apiKey: "YOUR_API_KEY",
  ///     history: [],
  ///   ),
  /// )
  /// ```
  OpenwebuiProvider({
    Iterable<ChatMessage>? history,
    required String model,
    required String host,
    String? apiKey,
  }): _history = history?.toList() ?? [],
      _model = model,
      _host = host,
      _apiKey = apiKey;

  final List<ChatMessage> _history;
  final String _model;
  final String _host;
  final String? _apiKey;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    _history.clear();
    final userMessage = ChatMessage(text: prompt, attachments: attachments, origin: MessageOrigin.user);
    final llmMessage = ChatMessage(text: "", attachments: [], origin: MessageOrigin.llm);
    _history.addAll([userMessage, llmMessage]);
    yield* _generateStream([userMessage], llmMessage);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage(text: prompt, attachments: attachments, origin: MessageOrigin.user);
    final llmResponse = ChatMessage(text: "", attachments: [], origin: MessageOrigin.llm);
    _history.add(userMessage);
    final messages = [..._history];
    _history.add(llmResponse);
    yield* _generateStream(messages, llmResponse);
  }

  Stream<String> _generateStream(List<ChatMessage> messages, ChatMessage llmResponse) async* {
    final httpRequest = http.Request('POST', Uri.parse("$_host/api/chat/completions"))
      ..headers.addAll({
        if(_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = _OwuiChatRequest(model: _model, messages: messages).toJsonString();

    final httpResponse = await http.Client().send(httpRequest);

    if (httpResponse.statusCode == 200) {
      final textStream = httpResponse.stream.transform(utf8.decoder);

      await for (var text in textStream) {
        final messages = text.split('\n');
        for (var message in messages) {
          if (message.startsWith('data: [DONE]')) {
            return;
          }
          if (message.isEmpty) continue;
          final cleanedMessage = message.replaceFirst('data: ', '').trim();
          try {
            final chatResponse = _OwuiChatResponse.fromJsonString(cleanedMessage);
            for (var choice in chatResponse.choices) {
              final content = choice.message.text ?? '';
              llmResponse.append(content);
              yield content;
            }
          } catch (e) {
            // just skip?
          }
        }
      }
    } else {
      throw Exception('HTTP request failed. Status: ${httpResponse.statusCode}, Reason: ${httpResponse.reasonPhrase}');
    }
  }

  @override
  get history => _history;

  @override
  set history(history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }
}
