---
name: pi-ai
description: "Patterns for using @mariozechner/pi-ai to build LLM-powered applications with streaming responses. Includes model configs, streaming patterns, tool calling, and React/Vue examples."
---

# pi-ai Skill for LLM Integration

This skill provides patterns for using `@mariozechner/pi-ai` to build LLM-powered applications with streaming responses.

## Installation

```bash
npm install @mariozechner/pi-ai
```

## Core Principles

1. **Always stream**: Use `stream()` or `streamSimple()` for real-time responses. Never use blocking `complete()` calls.
2. **User manages infrastructure**: Ollama and local model servers are started by the user, not the agent.
3. **Custom models for local**: Define custom `Model` objects for Ollama, LM Studio, or any OpenAI-compatible endpoint.
4. **Use TypeBox for tools**: Tool schemas should use `@sinclair/typebox` for runtime validation and TypeScript inference.

## Basic Setup

```typescript
import { Type, stream, complete, getModel, type Model, type Context, type Tool, type AssistantMessageEvent } from '@mariozechner/pi-ai';
```

## Model Configuration

### Local Model (Ollama)

```typescript
import { type Model } from '@mariozechner/pi-ai';

const ollamaModel: Model<'openai-completions'> = {
  id: 'llama3.2',
  name: 'Llama 3.2 (Local)',
  api: 'openai-completions',
  provider: 'ollama',
  baseUrl: 'http://localhost:11434/v1',
  reasoning: false,
  input: ['text'], // Add 'image' for vision models
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  contextWindow: 128000,
  maxTokens: 32000,
  compat: {
    supportsStore: false,
    supportsDeveloperRole: false,
  }
};
```

### Vision-Capable Local Model

```typescript
const ollamaVisionModel: Model<'openai-completions'> = {
  id: 'llava',
  name: 'LLaVA Vision (Local)',
  api: 'openai-completions',
  provider: 'ollama',
  baseUrl: 'http://localhost:11434/v1',
  reasoning: false,
  input: ['text', 'image'],
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  contextWindow: 32000,
  maxTokens: 4096,
  compat: { supportsStore: false, supportsDeveloperRole: false }
};
```

### Official Provider Model

```typescript
import { getModel } from '@mariozechner/pi-ai';

const model = getModel('openai', 'gpt-4o-mini');
// or
const model = getModel('anthropic', 'claude-3-5-sonnet-20241022');
```

## Streaming Patterns

### Basic Text Streaming

```typescript
const context: Context = {
  systemPrompt: 'You are a helpful assistant.',
  messages: [{ role: 'user', content: 'Hello!' }]
};

let fullText = '';

for await (const event of stream(ollamaModel, context, { apiKey: 'dummy' })) {
  switch (event.type) {
    case 'start':
      console.log('Starting...');
      break;
    case 'text_delta':
      fullText += event.delta;
      updateUI(event.delta); // Stream to UI
      break;
    case 'text_end':
      console.log('Text complete');
      break;
    case 'done':
      console.log('Done:', event.reason); // 'stop', 'length', 'toolUse'
      break;
    case 'error':
      console.error('Error:', event.error.errorMessage);
      break;
  }
}
```

### With Abort Signal

```typescript
const controller = new AbortController();

const streamPromise = (async () => {
  for await (const event of stream(model, context, { 
    signal: controller.signal 
  })) {
    // handle events
  }
})();

// Cancel if needed
controller.abort();
```

## Thinking/Reasoning Models

### Model Configuration

```typescript
const reasoningModel: Model<'openai-completions'> = {
  id: 'deepseek-r1',
  name: 'DeepSeek R1 (Local)',
  api: 'openai-completions',
  provider: 'ollama',
  baseUrl: 'http://localhost:11434/v1',
  reasoning: true, // Model supports reasoning
  input: ['text'],
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  contextWindow: 128000,
  maxTokens: 32000,
  compat: { 
    supportsStore: false, 
    supportsDeveloperRole: false,
    requiresThinkingAsText: true // Some local models need this
  }
};
```

### Streaming with Thinking

```typescript
let thinkingText = '';
let responseText = '';

for await (const event of stream(reasoningModel, context, { apiKey: 'dummy' })) {
  switch (event.type) {
    case 'thinking_start':
      showThinkingSection();
      break;
    case 'thinking_delta':
      thinkingText += event.delta;
      updateThinkingUI(event.delta);
      break;
    case 'thinking_end':
      hideThinkingSection();
      break;
    case 'text_delta':
      responseText += event.delta;
      updateResponseUI(event.delta);
      break;
  }
}
```

### Using Reasoning Levels (Remote Providers)

```typescript
import { streamSimple, type SimpleStreamOptions } from '@mariozechner/pi-ai';

// reasoning: 'minimal' | 'low' | 'medium' | 'high' | 'xhigh'
const options: SimpleStreamOptions = {
  reasoning: 'high',
  temperature: 0.7
};

for await (const event of streamSimple(model, context, options)) {
  // handle events
}
```

## Image Input

### Sending Images

```typescript
import type { UserMessage } from '@mariozechner/pi-ai';

async function fileToBase64(file: File): Promise<string> {
  const arrayBuffer = await file.arrayBuffer();
  const bytes = new Uint8Array(arrayBuffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function createImageMessage(file: File, text: string): Promise<UserMessage> {
  const base64 = await fileToBase64(file);
  const mimeType = file.type; // 'image/png', 'image/jpeg', etc.

  return {
    role: 'user',
    content: [
      { type: 'text', text },
      { type: 'image', data: base64, mimeType }
    ],
    timestamp: Date.now()
  };
}

// Use in context
const imageMessage = await createImageMessage(file, 'Describe this image');
const context: Context = {
  messages: [imageMessage]
};
```

### HTML File Input Example

```typescript
function createImageUploadHandler(onImage: (file: File) => void) {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/png,image/jpeg,image/webp';
  input.onchange = (e) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (file) onImage(file);
  };
  input.click();
}
```

## Tool Calling

### Define Tools with TypeBox

```typescript
import { Type, type Static, type TSchema } from '@mariozechner/pi-ai';
import type { Tool } from '@mariozechner/pi-ai';

const tools: Tool[] = [
  {
    name: 'get_weather',
    description: 'Get current weather for a location',
    parameters: Type.Object({
      location: Type.String({ description: 'City name or coordinates' }),
      units: Type.Optional(Type.Union([
        Type.Literal('celsius'),
        Type.Literal('fahrenheit')
      ], { default: 'celsius' }))
    })
  },
  {
    name: 'calculate',
    description: 'Perform a mathematical calculation',
    parameters: Type.Object({
      expression: Type.String({ description: 'Math expression to evaluate' })
    })
  }
];
```

### Handle Tool Call Events

```typescript
const context: Context = {
  systemPrompt: 'You are a helpful assistant with tools.',
  messages: [{ role: 'user', content: 'Whats the weather in Tokyo?' }],
  tools
};

const pendingToolCalls: Array<{ id: string; name: string; args: any }> = [];

for await (const event of stream(model, context)) {
  switch (event.type) {
    case 'toolcall_start':
      console.log('Tool call starting:', event.contentIndex);
      break;
    case 'toolcall_delta':
      // Arguments stream as partial JSON
      console.log('Partial args:', event.delta);
      break;
    case 'toolcall_end':
      console.log('Tool call complete:', event.toolCall.name);
      pendingToolCalls.push({
        id: event.toolCall.id,
        name: event.toolCall.name,
        args: event.toolCall.arguments
      });
      break;
    case 'done':
      if (event.reason === 'toolUse') {
        // Execute tools and continue conversation
        await executeToolsAndContinue(pendingToolCalls, context);
      }
      break;
  }
}
```

### Execute Tools and Continue

```typescript
import type { ToolResultMessage } from '@mariozechner/pi-ai';

async function executeToolsAndContinue(
  toolCalls: Array<{ id: string; name: string; args: any }>,
  context: Context,
  model: Model<any>
) {
  const toolResults: ToolResultMessage[] = [];

  for (const call of toolCalls) {
    let result: string;
    let isError = false;

    try {
      switch (call.name) {
        case 'get_weather':
          result = await getWeather(call.args.location, call.args.units);
          break;
        case 'calculate':
          result = String(eval(call.args.expression)); // Use safe eval!
          break;
        default:
          result = `Unknown tool: ${call.name}`;
          isError = true;
      }
    } catch (err) {
      result = err instanceof Error ? err.message : String(err);
      isError = true;
    }

    toolResults.push({
      role: 'toolResult',
      toolCallId: call.id,
      toolName: call.name,
      content: [{ type: 'text', text: result }],
      isError,
      timestamp: Date.now()
    });
  }

  // Add assistant's tool call message and results to context
  context.messages.push({
    role: 'assistant',
    content: toolCalls.map(call => ({
      type: 'toolCall' as const,
      id: call.id,
      name: call.name,
      arguments: call.args
    })),
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
    stopReason: 'toolUse',
    timestamp: Date.now()
  });

  // Add tool results
  context.messages.push(...toolResults);

  // Continue streaming
  for await (const event of stream(model, context)) {
    // Handle continued response
  }
}
```

## Context Management

### Building Multi-Turn Conversations

```typescript
import type { Context, Message } from '@mariozechner/pi-ai';

class ChatSession {
  private context: Context;
  private model: Model<any>;

  constructor(model: Model<any>, systemPrompt?: string) {
    this.model = model;
    this.context = {
      systemPrompt,
      messages: []
    };
  }

  async sendMessage(content: string, onDelta: (delta: string) => void) {
    // Add user message
    this.context.messages.push({
      role: 'user',
      content,
      timestamp: Date.now()
    });

    let response = '';

    for await (const event of stream(this.model, this.context)) {
      if (event.type === 'text_delta') {
        response += event.delta;
        onDelta(event.delta);
      }
    }

    // Assistant response is automatically tracked by the stream's result
    // Or manually add it if needed
  }

  getMessages(): Message[] {
    return this.context.messages;
  }

  exportContext(): Context {
    return JSON.parse(JSON.stringify(this.context));
  }

  importContext(context: Context) {
    this.context = context;
  }
}
```

## Error Handling

```typescript
for await (const event of stream(model, context)) {
  switch (event.type) {
    case 'error':
      // stopReason is 'error' or 'aborted'
      console.error('Stream failed:', event.error.errorMessage);
      
      if (event.reason === 'aborted') {
        // User cancelled - can resume
        console.log('Request was aborted');
      } else {
        // Server/model error
        showErrorToUser(event.error.errorMessage);
      }
      break;
  }
}
```

### Retry Logic

```typescript
async function streamWithRetry(
  model: Model<any>,
  context: Context,
  maxRetries = 3
): Promise<string> {
  let lastError: string = '';
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      let result = '';
      
      for await (const event of stream(model, context)) {
        if (event.type === 'text_delta') {
          result += event.delta;
        } else if (event.type === 'done') {
          return result;
        } else if (event.type === 'error') {
          throw new Error(event.error.errorMessage);
        }
      }
      
      return result;
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
      console.log(`Attempt ${attempt + 1} failed: ${lastError}`);
      await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
  
  throw new Error(`Failed after ${maxRetries} attempts: ${lastError}`);
}
```

## Complete Examples

### React Hook for Streaming Chat

```typescript
import { useState, useCallback, useRef } from 'react';
import { stream, type Model, type Context, type AssistantMessageEvent } from '@mariozechner/pi-ai';

interface UseStreamingChatOptions {
  model: Model<any>;
  systemPrompt?: string;
  apiKey?: string;
}

interface Message {
  role: 'user' | 'assistant';
  content: string;
  thinking?: string;
}

export function useStreamingChat({ model, systemPrompt, apiKey }: UseStreamingChatOptions) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [currentThinking, setCurrentThinking] = useState('');
  const abortControllerRef = useRef<AbortController | null>(null);

  const sendMessage = useCallback(async (content: string) => {
    if (isStreaming) return;

    // Add user message
    const userMsg: Message = { role: 'user', content };
    setMessages(prev => [...prev, userMsg]);
    setIsStreaming(true);

    // Build context
    const context: Context = {
      systemPrompt,
      messages: messages.map(m => ({
        role: m.role,
        content: m.content,
        timestamp: Date.now()
      })).concat([{
        role: 'user',
        content,
        timestamp: Date.now()
      }])
    };

    abortControllerRef.current = new AbortController();
    
    let responseText = '';
    let thinkingText = '';

    try {
      for await (const event of stream(model, context, {
        apiKey,
        signal: abortControllerRef.current      })) {
        switch (event.type) {
          case 'text_delta':
            responseText += event.delta;
            setMessages(prev => {
              const newMessages = [...prev];
              const lastMsg = newMessages[newMessages.length - 1];
              if (lastMsg?.role === 'assistant') {
                lastMsg.content = responseText;
              } else {
                newMessages.push({ role: 'assistant', content: responseText });
              }
              return newMessages;
            });
            break;
          case 'thinking_delta':
            thinkingText += event.delta;
            setCurrentThinking(thinkingText);
            break;
        }
      }
    } catch (err) {
      console.error("Streaming error:", err);
    } finally {
      setIsStreaming(false);
      setCurrentThinking("");
      abortControllerRef.current = null;
    }
  }, [model, messages, systemPrompt, apiKey]);

  const stop = useCallback(() => {
    abortControllerRef.current?.abort();
  }, []);

  return { messages, sendMessage, stop, isStreaming, currentThinking };
}
```

### Vue Composable for Streaming Chat

```typescript
import { ref, computed } from 'vue';
import { stream, type Model, type Context } from '@mariozechner/pi-ai';

export function useStreamingChat(model: Model<any>, options?: { systemPrompt?: string; apiKey?: string }) {
  const messages = ref<Array<{ role: 'user' | 'assistant'; content: string }>>([]);
  const isStreaming = ref(false);
  const currentResponse = ref("");
  const abortController = ref<AbortController | null>(null);

  async function sendMessage(content: string) {
    if (isStreaming.value) return;

    messages.value.push({ role: 'user', content });
    isStreaming.value = true;
    currentResponse.value = "";

    const context: Context = {
      systemPrompt: options?.systemPrompt,
      messages: messages.value.map(m => ({
        role: m.role,
        content: m.content,
        timestamp: Date.now()
      }))
    };

    abortController.value = new AbortController();

    try {
      for await (const event of stream(model, context, {
        apiKey: options?.apiKey,
        signal: abortController.value.signal
      })) {
        if (event.type === 'text_delta') {
          currentResponse.value += event.delta;
        }
      }

      messages.value.push({
        role: 'assistant',
        content: currentResponse.value
      });
    } catch (err) {
      console.error("Streaming error:", err);
    } finally {
      isStreaming.value = false;
      abortController.value = null;
    }
  }

  function stop() {
    abortController.value?.abort();
  }

  return {
    messages: computed(() => messages.value),
    sendMessage,
    stop,
    isStreaming: computed(() => isStreaming.value),
    currentResponse: computed(() => currentResponse.value)
  };
}
```

## Quick Reference

### Event Types Reference

| Event | Description | Data Available |
|-------|-------------|----------------|
| `start` | Stream started | `event.partial` - initial message structure |
| `text_start` | Text block started | `event.contentIndex`, `event.partial` |
| `text_delta` | Text chunk received | `event.delta` (string), `event.contentIndex` |
| `text_end` | Text block complete | `event.content`, `event.contentIndex` |
| `thinking_start` | Thinking block started | `event.contentIndex`, `event.partial` |
| `thinking_delta` | Thinking chunk received | `event.delta` (string), `event.contentIndex` |
| `thinking_end` | Thinking block complete | `event.content`, `event.contentIndex` |
| `toolcall_start` | Tool call started | `event.contentIndex`, `event.partial` |
| `toolcall_delta` | Tool args JSON chunk | `event.delta` (JSON string), `event.contentIndex` |
| `toolcall_end` | Tool call complete | `event.toolCall` (full tool call object) |
| `done` | Stream successful | `event.reason` ('stop', 'length', 'toolUse'), `event.message` |
| `error` | Stream failed | `event.reason` ('error' or 'aborted'), `event.error` |

### Model Interface Fields

```typescript
interface Model<TApi extends Api> {
  id: string;                    // Model ID (e.g., 'gpt-4o', 'llama3.2')
  name: string;                  // Display name
  api: TApi;                     // API type ('openai-completions', 'anthropic-messages', etc.)
  provider: Provider;            // Provider identifier
  baseUrl: string;               // API base URL
  reasoning: boolean;            // Supports reasoning/thinking
  input: ('text' | 'image')[];   // Supported input types
  cost: {                        // Cost per million tokens
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
  contextWindow: number;         // Max context in tokens
  maxTokens: number;             // Max response tokens
  headers?: Record<string, string>;  // Custom headers
  compat?: OpenAICompletionsCompat;  // Compatibility settings for openai-completions
}
```

### Compatibility Settings for Local Models

```typescript
compat: {
  supportsStore: false,              // Disable 'store' field
  supportsDeveloperRole: false,      // Use 'system' role instead of 'developer'
  supportsReasoningEffort: false,    // Disable reasoning_effort
  supportsUsageInStreaming: true,    // Include usage in streaming responses
  requiresThinkingAsText: true,      // Wrap thinking in <thinking> tags
  thinkingFormat: 'openai' | 'openrouter' | 'qwen' | 'qwen-chat-template',
  maxTokensField: 'max_tokens' | 'max_completion_tokens',
  supportsStrictMode: false,         // Disable strict tool mode
}
```

### Content Block Types

```typescript
// Text content
type TextContent = {
  type: 'text';
  text: string;
  textSignature?: string;
};

// Thinking content
type ThinkingContent = {
  type: 'thinking';
  thinking: string;
  thinkingSignature?: string;
  redacted?: boolean;
};

// Image content (input)
type ImageContent = {
  type: 'image';
  data: string;      // base64
  mimeType: string;  // 'image/png', 'image/jpeg', etc.
};

// Tool call
type ToolCall = {
  type: 'toolCall';
  id: string;
  name: string;
  arguments: Record<string, any>;
  thoughtSignature?: string;
};
```

### Common Import Pattern

```typescript
import { 
  Type, 
  stream, 
  streamSimple,
  getModel, 
  getModels, 
  getProviders,
  calculateCost,
  supportsXhigh,
  modelsAreEqual,
  type Model, 
  type Context, 
  type Tool, 
  type Message,
  type UserMessage,
  type AssistantMessage,
  type ToolResultMessage,
  type AssistantMessageEvent,
  type StreamOptions,
  type SimpleStreamOptions
} from '@mariozechner/pi-ai';
```

## Best Practices Summary

1. **Always use `stream()`** - Never `complete()` for UI work
2. **Check `model.input`** before sending images
3. **Handle `thinking_delta`** separately from `text_delta` for reasoning models
4. **Use `AbortController`** to allow cancellation
5. **Validate tool args** with TypeBox schemas
6. **Accumulate partial JSON** during `toolcall_delta` events
7. **Check `stopReason` on `done`** to handle toolUse appropriately
8. **Add timestamps** to all messages for proper context ordering
9. **Use `apiKey: 'dummy'`** for local models that do not need auth
10. **Set compat flags** correctly for OpenAI-compatible local servers
