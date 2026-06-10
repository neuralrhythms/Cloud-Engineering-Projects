# 🤖 RAG Architecture

> Retrieval-Augmented Generation pipeline combining document ingestion, vector embeddings, semantic retrieval, and LLM inference.

---

## Overview

Enterprise RAG system that ingests organizational documents, generates embeddings, stores them in a vector database, and retrieves relevant context for LLM-powered question answering.

## Architecture

```mermaid
graph TD
    subgraph "Document Ingestion"
        UPLOAD[Document Upload<br/>PDF, DOCX, TXT]
        S3_RAW[S3 Raw Documents]
        LAMBDA_PROC[Lambda<br/>Document Processor]
        CHUNK[Text Chunking<br/>Semantic Splitting]
    end
    
    subgraph "Embedding Pipeline"
        EMBED_MODEL[Bedrock Embeddings<br/>Titan / Cohere]
        VECTOR_DB[(OpenSearch Serverless<br/>Vector Index)]
    end
    
    subgraph "Retrieval & Generation"
        QUERY[User Query]
        QUERY_EMBED[Query Embedding]
        KNN[k-NN Search<br/>Top-K Retrieval]
        CONTEXT[Context Assembly]
        LLM[Bedrock Claude<br/>LLM Inference]
        RESPONSE[Generated Response<br/>With Citations]
    end
    
    UPLOAD --> S3_RAW
    S3_RAW --> LAMBDA_PROC
    LAMBDA_PROC --> CHUNK
    CHUNK --> EMBED_MODEL
    EMBED_MODEL --> VECTOR_DB
    
    QUERY --> QUERY_EMBED
    QUERY_EMBED --> EMBED_MODEL
    QUERY_EMBED --> KNN
    KNN --> VECTOR_DB
    KNN --> CONTEXT
    CONTEXT --> LLM
    LLM --> RESPONSE
```

## Key Components

### Document Ingestion

```mermaid
graph LR
    PDF[PDF Upload] --> TEXTRACT[Amazon Textract<br/>OCR + Table Extraction]
    TEXTRACT --> CLEAN[Text Cleaning<br/>Remove Headers/Footers]
    CLEAN --> CHUNK[Semantic Chunking<br/>500-1000 tokens<br/>50 token overlap]
    CHUNK --> META[Metadata Enrichment<br/>Source, Page, Date]
    META --> EMBED[Generate Embeddings<br/>1536 dimensions]
    EMBED --> STORE[Store in Vector DB<br/>With Metadata]
```

### Retrieval Pipeline

| Step | Component | Purpose |
|------|-----------|---------|
| 1 | Query embedding | Convert question to vector |
| 2 | k-NN search | Find top-K similar chunks |
| 3 | Reranking | Score relevance of retrieved chunks |
| 4 | Context assembly | Format chunks with metadata |
| 5 | Prompt construction | System + context + question |
| 6 | LLM inference | Generate answer with citations |
| 7 | Response formatting | Clean output with source references |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Vector DB | OpenSearch Serverless | Managed, scalable, k-NN built-in |
| Embedding model | Titan Embeddings v2 | AWS-native, 1536 dimensions, multilingual |
| LLM | Claude 3 Sonnet (Bedrock) | Strong reasoning, 200K context, cost-effective |
| Chunking | Semantic (sentence boundaries) | Preserves meaning better than fixed-size |
| Chunk size | 500-1000 tokens, 50 overlap | Balance between context and precision |

## Services Used

| Service | Purpose |
|---------|---------|
| Amazon Bedrock | Embeddings + LLM inference |
| OpenSearch Serverless | Vector storage and k-NN search |
| Lambda | Document processing, orchestration |
| S3 | Raw document storage |
| Textract | PDF/image OCR |
| Step Functions | Ingestion pipeline orchestration |
| API Gateway | REST API for queries |
| CloudWatch | Monitoring, latency tracking |

---

➡️ [Back to AI Workloads](../) | [Back to AWS](../../)
