# 🤖 AI Chatbot

> Conversational AI with content guardrails, context management, and multi-turn dialogue.

## Architecture

```mermaid
graph LR
    UI[Web Chat UI] --> APIGW[API Gateway<br/>WebSocket]
    APIGW --> LAMBDA[Lambda<br/>Chat Handler]
    LAMBDA --> SESSION[DynamoDB<br/>Session Store]
    LAMBDA --> GUARD[Bedrock Guardrails<br/>Content Safety]
    GUARD --> BEDROCK[Bedrock Claude<br/>Inference]
    LAMBDA --> KB[Knowledge Base<br/>RAG Context]
    BEDROCK --> LAMBDA --> APIGW --> UI
```

## Features

- Multi-turn conversation with history management
- Streaming responses via WebSocket
- Content guardrails (PII filtering, topic restrictions)
- RAG-based grounding with knowledge base
- Session persistence in DynamoDB
- Token usage tracking and cost alerts

---

➡️ [Back to AI Workloads](../) | [Back to AWS](../../)
