# 🤖 Knowledge Base Search

> Semantic search powered by vector embeddings and Amazon Bedrock Knowledge Bases.

## Architecture

```mermaid
graph TD
    subgraph "Data Sources"
        S3[S3 Documents]
        CONFLUENCE[Confluence Pages]
        WEB[Web Crawl]
    end
    
    subgraph "Amazon Bedrock Knowledge Base"
        SYNC[Data Source Sync]
        CHUNK[Chunking Strategy]
        EMBED[Titan Embeddings v2]
        VECTOR[(OpenSearch Serverless<br/>Vector Store)]
    end
    
    subgraph "Search Interface"
        QUERY[Search Query]
        RETRIEVE[RetrieveAndGenerate API]
        RESPONSE[Contextual Answer<br/>+ Source Citations]
    end
    
    S3 --> SYNC
    CONFLUENCE --> SYNC
    WEB --> SYNC
    SYNC --> CHUNK --> EMBED --> VECTOR
    
    QUERY --> RETRIEVE --> VECTOR
    VECTOR --> RETRIEVE --> RESPONSE
```

## Key Capabilities

- Managed ingestion from S3, web crawlers, Confluence
- Automatic chunking and embedding generation
- Built-in RetrieveAndGenerate API
- Source citations with each answer
- Metadata filtering for scoped search
- Automatic re-sync on source changes

---

➡️ [Back to AI Workloads](../) | [Back to AWS](../../)
