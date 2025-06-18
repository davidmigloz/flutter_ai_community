# Flutter AI Providers Examples

This directory contains example implementations showing how to use various AI providers with the Flutter AI Toolkit.

## Available Examples

### OpenAI Provider Example

The `openai.dart` file demonstrates how to integrate the OpenAI provider:

- **File**: `lib/openai.dart`
- **Provider**: OpenAIProvider with GPT-4o
- **Features**: Basic chat interface with streaming responses and image support

To run this example:

```bash
flutter run lib/openai.dart
```

### Anthropic Provider Example

The `anthropic.dart` file demonstrates how to integrate the Anthropic provider:

- **File**: `lib/anthropic.dart`
- **Provider**: AnthropicProvider with Claude
- **Features**: Basic chat interface with streaming responses and image support

To run this example:

```bash
flutter run lib/anthropic.dart
```

### Ollama Provider Example

The `ollama.dart` file demonstrates how to integrate the Ollama provider:

- **File**: `lib/ollama.dart`
- **Provider**: OllamaProvider with local models
- **Features**: Basic chat interface with streaming responses and vision support

To run this example (requires Ollama running locally):

```bash
flutter run lib/ollama.dart
```

### Llama.cpp Provider Example

The `llama.dart` file demonstrates how to integrate the Llama.cpp provider:

- **File**: `lib/llama.dart`
- **Provider**: LlamaProvider with local GGUF models
- **Features**: Basic chat interface with local model execution

To run this example:

```bash
flutter run lib/llama.dart
```

### Open WebUI Provider Example

The `openwebui.dart` file demonstrates how to integrate the Open WebUI provider:

- **File**: `lib/openwebui.dart`
- **Provider**: OpenWebUIProvider
- **Features**: Basic chat interface with Open WebUI backend

To run this example:

```bash
flutter run lib/openwebui.dart
```

### Dartantic Provider Example

The `dartantic.dart` file demonstrates how to integrate the Dartantic AI provider:

- **File**: `lib/dartantic.dart`
- **Provider**: DartanticProvider with Google Gemini
- **Features**: Basic chat interface with streaming responses

To run this example:

```bash
flutter run lib/dartantic.dart
```

## General Setup

**Important**: Make sure to configure your API keys properly before running any examples that require them. Never commit API keys to version control.

For local providers (Ollama, Llama.cpp), ensure the respective services are properly installed and running.

## Default Example

The `main.dart` file contains the default Ollama example that runs when you use `flutter run` without specifying a target.
