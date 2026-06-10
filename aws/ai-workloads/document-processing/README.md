# 🤖 Document Processing Pipeline

> End-to-end pipeline: PDF Upload → S3 → Lambda → Textract → Chunking → Embeddings → Knowledge Base → Bedrock → Chat Interface

---

## Architecture

```mermaid
graph TD
    subgraph "Input"
        USER[User Upload]
        API[API Gateway<br/>Pre-signed URL]
    end
    
    subgraph "Storage"
        S3_RAW[S3: Raw Documents]
        S3_PROC[S3: Processed Text]
    end
    
    subgraph "Processing Pipeline"
        TRIGGER[S3 Event Trigger]
        SFN[Step Functions<br/>Orchestrator]
        TEXTRACT[Amazon Textract<br/>OCR + Tables + Forms]
        LAMBDA_CHUNK[Lambda: Chunking<br/>Semantic Split]
        LAMBDA_EMBED[Lambda: Embeddings<br/>Bedrock Titan]
    end
    
    subgraph "Knowledge Storage"
        OPENSEARCH[(OpenSearch<br/>Vector Index)]
        KB[Bedrock Knowledge Base]
    end
    
    subgraph "Query Interface"
        CHAT[Chat Interface]
        APIGW[API Gateway WebSocket]
        LAMBDA_Q[Lambda: Query Handler]
        BEDROCK[Bedrock Claude<br/>RAG Response]
    end
    
    USER --> API --> S3_RAW
    S3_RAW --> TRIGGER --> SFN
    SFN --> TEXTRACT
    TEXTRACT --> S3_PROC
    S3_PROC --> LAMBDA_CHUNK
    LAMBDA_CHUNK --> LAMBDA_EMBED
    LAMBDA_EMBED --> OPENSEARCH
    OPENSEARCH --> KB
    
    CHAT --> APIGW --> LAMBDA_Q
    LAMBDA_Q --> KB --> BEDROCK
    BEDROCK --> LAMBDA_Q --> CHAT
```

## Processing Steps

| Step | Service | Action |
|------|---------|--------|
| 1. Upload | API Gateway + S3 | Pre-signed URL → S3 put |
| 2. Trigger | S3 Event → Step Functions | Start processing pipeline |
| 3. Extract | Amazon Textract | OCR text, tables, forms from PDF |
| 4. Clean | Lambda | Remove headers, footers, page numbers |
| 5. Chunk | Lambda | Semantic chunking (500-1000 tokens) |
| 6. Embed | Bedrock Titan Embeddings | Generate 1536-dim vectors |
| 7. Store | OpenSearch Serverless | Index vectors with metadata |
| 8. Query | Bedrock Knowledge Base | Retrieve + generate answer |

## Supported Formats

| Format | Extraction Method |
|--------|------------------|
| PDF (text) | Textract DetectDocumentText |
| PDF (scanned) | Textract OCR |
| PDF (tables) | Textract AnalyzeDocument |
| DOCX | Lambda (python-docx) |
| TXT/MD | Direct read |
| Images (PNG/JPEG) | Textract OCR |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Orchestration | Step Functions | Visual workflow, error handling, retries |
| OCR | Textract | Best AWS-native OCR, handles tables/forms |
| Chunking | Semantic (sentence boundaries) | Preserves meaning across chunk boundaries |
| Vector DB | OpenSearch Serverless | Managed, auto-scaling, k-NN native |
| Chat interface | WebSocket API | Real-time streaming responses |

---

➡️ [Back to AI Workloads](../) | [Back to AWS](../../)
