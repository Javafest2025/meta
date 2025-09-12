# ScholarAI Session-Based Chat System Pipeline Documentation

## Overview

This document provides a comprehensive overview of the ScholarAI session-based chat system, covering the entire pipeline from PDF extraction to AI-powered contextual responses. The system enables users to have intelligent conversations about academic papers with proper session management, similar to ChatGPT.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Data Flow Pipeline](#data-flow-pipeline)
3. [PDF Extraction Pipeline](#pdf-extraction-pipeline)
4. [Chat Session Management](#chat-session-management)
5. [AI Context Processing](#ai-context-processing)
6. [Frontend Implementation](#frontend-implementation)
7. [Backend Services](#backend-services)
8. [Database Schema](#database-schema)
9. [API Endpoints](#api-endpoints)
10. [Deployment & Configuration](#deployment--configuration)
11. [Troubleshooting](#troubleshooting)
12. [Future Enhancements](#future-enhancements)

## System Architecture

```mermaid
graph TB
    User[User Interface] --> Frontend[Frontend - Next.js]
    Frontend --> ApiGateway[API Gateway - Spring Cloud]
    ApiGateway --> ProjectService[Project Service]
    ApiGateway --> ExtractorService[PDF Extractor Service]
    ApiGateway --> PaperSearchService[Paper Search Service]
    
    ProjectService --> ProjectDB[(Project Database)]
    ProjectService --> Redis[(Redis Cache)]
    ProjectService --> RabbitMQ[RabbitMQ]
    
    ExtractorService --> Grobid[GROBID PDF Parser]
    ExtractorService --> ProjectDB
    
    PaperSearchService --> ArxivAPI[Arxiv API]
    PaperSearchService --> SemanticScholar[Semantic Scholar API]
    
    ProjectService --> AIService[AI Processing Service]
    AIService --> OpenAI[OpenAI GPT API]
```

### Key Components

- **Frontend**: Next.js React application with TypeScript
- **API Gateway**: Spring Cloud Gateway for request routing
- **Project Service**: Core business logic for papers and chat
- **PDF Extractor**: Python FastAPI service for document processing
- **Paper Search**: Python FastAPI service for paper discovery
- **GROBID**: Open-source PDF parsing service
- **Database**: PostgreSQL for persistent storage
- **Cache**: Redis for session and performance optimization
- **Message Queue**: RabbitMQ for async processing

## Data Flow Pipeline

### 1. Paper Upload & Processing Flow

```
PDF Upload → Extraction Request → GROBID Processing → Structured Data → Database Storage → Chat Ready
```

#### Detailed Steps:

1. **PDF Upload**
   - User uploads PDF through frontend
   - File stored in temporary storage
   - Upload metadata recorded

2. **Extraction Initiation**
   - Frontend calls `/api/papers/{paperId}/extract`
   - Project service validates paper existence
   - Extraction job queued in RabbitMQ

3. **GROBID Processing**
   - PDF Extractor service consumes queue message
   - GROBID parses PDF structure
   - Extracts: title, authors, abstract, sections, figures, tables, references

4. **Structured Data Storage**
   - Parsed content stored in PostgreSQL
   - Full-text search indexes created
   - Paper marked as "extraction complete"

5. **Chat System Activation**
   - Paper becomes available for chat sessions
   - Context preparation for AI processing

### 2. Chat Session Flow

```
User Message → Session Creation/Continue → Context Retrieval → AI Processing → Response Generation → Storage → Frontend Display
```

#### Detailed Steps:

1. **Session Initialization**
   - User opens chat for a paper
   - System checks for existing sessions
   - Creates new session if none exists

2. **Message Processing**
   - User sends message through frontend
   - Message validated and stored
   - Context retrieval initiated

3. **AI Response Generation**
   - Paper content retrieved from database
   - Context prepared for AI model
   - OpenAI API called with structured prompt
   - Response generated and validated

4. **Response Storage & Display**
   - AI response stored in database
   - Session metadata updated
   - Response sent to frontend
   - Real-time display to user

## PDF Extraction Pipeline

### Architecture

```
PDF File → GROBID → Structured XML → Parser → Database Entities
```

### GROBID Integration

**Service**: Docker container running GROBID 0.8.0
**Port**: 8070
**Health Check**: `/api/isalive`

#### Extraction Process

1. **Document Upload**
   ```python
   def extract_with_grobid(pdf_path: str) -> dict:
       files = {'input': open(pdf_path, 'rb')}
       response = requests.post(
           f"{GROBID_URL}/api/processFulltextDocument",
           files=files,
           data={'consolidateHeader': '1', 'consolidateCitations': '1'}
       )
       return parse_grobid_xml(response.text)
   ```

2. **XML Parsing**
   - TEI XML structure parsed
   - Sections extracted with hierarchy
   - Figures and tables identified
   - Citations and references processed

3. **Database Storage**
   ```sql
   -- Core paper entity
   INSERT INTO papers (id, title, abstract, doi, arxiv_id)
   
   -- Authors with affiliations
   INSERT INTO paper_authors (paper_id, author_id, position)
   
   -- Document sections
   INSERT INTO paper_sections (paper_id, title, content, section_type, position)
   
   -- Figures and tables
   INSERT INTO paper_figures (paper_id, caption, figure_type, position)
   ```

### Extraction Quality Metrics

- **Text Accuracy**: 95%+ for well-formatted PDFs
- **Structure Recognition**: 90%+ for academic papers
- **Citation Extraction**: 85%+ precision
- **Processing Time**: 30-60 seconds per paper

## Chat Session Management

### Session Lifecycle

```
Session Creation → Message Exchange → Title Generation → Persistence → Retrieval
```

### Session States

- **CREATED**: Initial state after creation
- **ACTIVE**: Currently in use
- **INACTIVE**: No recent activity
- **ARCHIVED**: Long-term storage

### Auto-Title Generation

**Trigger**: First message sent in session
**Process**: 
1. AI analyzes first user message
2. Generates descriptive title (max 50 chars)
3. Title updated in real-time
4. Session list refreshed

**Example**:
- User message: "What methodology did the authors use?"
- Generated title: "Research Methodology Analysis"

### Session Sorting & Organization

```javascript
// Sorting logic in frontend
const sortedSessions = sessions.sort((a, b) => {
    // Invalid sessions go to bottom
    const aValid = a.lastMessageAt && a.title;
    const bValid = b.lastMessageAt && b.title;
    
    if (!aValid && bValid) return 1;
    if (aValid && !bValid) return -1;
    if (!aValid && !bValid) return 0;
    
    // Sort by latest activity
    return new Date(b.lastMessageAt) - new Date(a.lastMessageAt);
});
```

## AI Context Processing

### Context Preparation Pipeline

```
User Message → Relevant Content Retrieval → Context Assembly → Prompt Engineering → AI API Call
```

### Content Retrieval Strategy

1. **Full-Text Search**
   - PostgreSQL `tsvector` search
   - Ranked by relevance score
   - Section-level granularity

2. **Semantic Matching**
   - Keyword extraction from user query
   - Section content scoring
   - Author and title matching

3. **Context Assembly**
   ```java
   public String assembleContext(String userMessage, Paper paper) {
       StringBuilder context = new StringBuilder();
       
       // Paper metadata
       context.append("Title: ").append(paper.getTitle()).append("\n");
       context.append("Authors: ").append(formatAuthors(paper.getAuthors())).append("\n");
       context.append("Abstract: ").append(paper.getAbstract()).append("\n\n");
       
       // Relevant sections
       List<Section> relevantSections = findRelevantSections(userMessage, paper);
       for (Section section : relevantSections) {
           context.append("## ").append(section.getTitle()).append("\n");
           context.append(section.getContent()).append("\n\n");
       }
       
       return context.toString();
   }
   ```

### Prompt Engineering

**Template Structure**:
```
You are an AI assistant helping users understand academic papers.

Paper Information:
Title: {title}
Authors: {authors}
Abstract: {abstract}

Relevant Content:
{sections}

User Question: {userMessage}

Please provide a comprehensive answer based solely on the paper content provided above.
```

### AI Response Processing

1. **API Call Configuration**
   ```java
   OpenAIRequest request = OpenAIRequest.builder()
       .model("gpt-4-turbo-preview")
       .messages(messages)
       .maxTokens(1000)
       .temperature(0.3)
       .build();
   ```

2. **Response Validation**
   - Check for hallucinations
   - Validate against paper content
   - Format for frontend display

3. **Context Metadata**
   ```java
   ContextMetadata metadata = ContextMetadata.builder()
       .sectionsUsed(sectionsUsed)
       .figuresReferenced(figuresReferenced)
       .confidenceScore(calculateConfidence())
       .build();
   ```

## Frontend Implementation

### Technology Stack

- **Framework**: Next.js 15.2.4
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: React Hooks
- **HTTP Client**: Fetch API with authentication wrapper

### Chat Component Architecture

```
ChatContainer (Main Component)
├── ChatComposer (Message Input)
├── ChatMessage (Message Display)
├── SessionList (Chat History)
└── ChatContext (Session Management)
```

### Key Frontend Components

#### 1. ChatContainer.tsx
```typescript
interface ChatContainerProps {
    paperId: string;
    initialSessionId?: string;
    onSessionChange?: (sessionId: string) => void;
}

const ChatContainer: React.FC<ChatContainerProps> = ({
    paperId,
    initialSessionId,
    onSessionChange
}) => {
    const [messages, setMessages] = useState<Message[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);
    const [chatSessions, setChatSessions] = useState<ChatSession[]>([]);
    const [chatName, setChatName] = useState("New Chat");
    
    // Component logic...
};
```

#### 2. API Integration (chat.ts)
```typescript
export interface ChatResponse {
    sessionId: string;
    response: string;
    title?: string; // AI-generated title
    timestamp: string;
    success: boolean;
    error?: string;
    context?: ContextMetadata;
}

export const createChatSession = async (
    paperId: string,
    initialMessage: string,
    customTitle?: string
): Promise<ChatResponse> => {
    // Implementation...
};

export const continueChatSession = async (
    paperId: string,
    sessionId: string,
    message: string
): Promise<ChatResponse> => {
    // Implementation...
};
```

### Real-time Features

1. **Live Title Updates**
   - AI generates title from first message
   - Frontend updates immediately
   - No page refresh required

2. **Message Status Indicators**
   - Sending: Loading spinner
   - Sent: Checkmark
   - Error: Error icon with retry

3. **Session Management**
   - Auto-save on each message
   - Session switching without data loss
   - Persistent chat history

## Backend Services

### Project Service (Java Spring Boot)

#### Core Controllers

1. **PaperContextChatController**
   ```java
   @RestController
   @RequestMapping("/api/papers/{paperId}/chat")
   public class PaperContextChatController {
       
       @PostMapping("/sessions")
       public ResponseEntity<ChatSessionResponse> createChatSession(
           @PathVariable UUID paperId,
           @Valid @RequestBody CreateChatSessionRequest request
       ) {
           // Implementation...
       }
       
       @PostMapping("/sessions/{sessionId}/messages")
       public ResponseEntity<PaperChatResponse> continueChat(
           @PathVariable UUID paperId,
           @PathVariable UUID sessionId,
           @Valid @RequestBody PaperChatRequest request
       ) {
           // Implementation...
       }
   }
   ```

2. **ChatSessionService**
   ```java
   @Service
   @Transactional
   public class ChatSessionService {
       
       public ChatSessionResponse createSession(UUID paperId, CreateChatSessionRequest request) {
           // Validate paper extraction status
           // Create new chat session
           // Process initial message
           // Generate AI response
           // Return session with first response
       }
       
       public PaperChatResponse continueChat(UUID sessionId, PaperChatRequest request) {
           // Validate session exists
           // Store user message
           // Generate AI response
           // Update session metadata
           // Return response
       }
   }
   ```

#### Data Transfer Objects

```java
// Request DTOs
public class CreateChatSessionRequest {
    private String initialMessage;
    private String customTitle;
    private String selectedText;
    private SelectionContext selectionContext;
}

public class PaperChatRequest {
    private String message;
    private String selectedText;
    private SelectionContext selectionContext;
}

// Response DTOs
public class ChatSessionResponse {
    private UUID sessionId;
    private UUID paperId;
    private String title;
    private Instant createdAt;
    private Instant lastMessageAt;
    private Integer messageCount;
    private Boolean isActive;
    private String lastMessagePreview;
}

public class PaperChatResponse {
    private UUID sessionId;
    private String response;
    private ContextMetadata context;
    private Instant timestamp;
    private Boolean success;
    private String error;
}
```

### PDF Extractor Service (Python FastAPI)

#### Architecture
```python
from fastapi import FastAPI, HTTPException
from sqlalchemy import create_engine
import requests
from typing import Optional

app = FastAPI(title="PDF Extractor Service")

class ExtractionService:
    def __init__(self):
        self.grobid_url = "http://grobid:8070"
        self.db_engine = create_engine(DATABASE_URL)
    
    async def extract_paper(self, paper_id: str, pdf_path: str) -> dict:
        # GROBID extraction
        extracted_data = await self.extract_with_grobid(pdf_path)
        
        # Database storage
        await self.store_extracted_data(paper_id, extracted_data)
        
        # Notification
        await self.notify_extraction_complete(paper_id)
        
        return {"status": "completed", "paper_id": paper_id}
```

#### GROBID Integration
```python
async def extract_with_grobid(self, pdf_path: str) -> dict:
    """Extract structured data from PDF using GROBID"""
    
    files = {'input': open(pdf_path, 'rb')}
    data = {
        'consolidateHeader': '1',
        'consolidateCitations': '1',
        'includeRawCitations': '1'
    }
    
    response = requests.post(
        f"{self.grobid_url}/api/processFulltextDocument",
        files=files,
        data=data,
        timeout=300
    )
    
    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="GROBID extraction failed")
    
    return self.parse_grobid_xml(response.text)
```

## Database Schema

### Core Tables

#### 1. Papers Table
```sql
CREATE TABLE papers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(1000) NOT NULL,
    abstract TEXT,
    doi VARCHAR(255),
    arxiv_id VARCHAR(50),
    pdf_url VARCHAR(1000),
    extraction_status VARCHAR(50) DEFAULT 'PENDING',
    extraction_completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Full-text search index
CREATE INDEX papers_title_search_idx ON papers USING gin(to_tsvector('english', title));
CREATE INDEX papers_abstract_search_idx ON papers USING gin(to_tsvector('english', abstract));
```

#### 2. Authors Table
```sql
CREATE TABLE authors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL UNIQUE,
    primary_affiliation VARCHAR(500),
    orcid_id VARCHAR(255),
    semantic_scholar_id VARCHAR(255),
    citation_count INTEGER,
    h_index INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- String representation for AI context
ALTER TABLE authors ADD CONSTRAINT authors_tostring_method 
CHECK (name IS NOT NULL);
```

#### 3. Paper Sections Table
```sql
CREATE TABLE paper_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    title VARCHAR(500),
    content TEXT NOT NULL,
    section_type VARCHAR(50), -- 'introduction', 'methodology', 'results', etc.
    position INTEGER,
    parent_section_id UUID REFERENCES paper_sections(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Full-text search index
CREATE INDEX paper_sections_content_search_idx ON paper_sections 
USING gin(to_tsvector('english', content));
```

#### 4. Chat Sessions Table
```sql
CREATE TABLE chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    user_id UUID, -- Future authentication integration
    title VARCHAR(200) DEFAULT 'New Chat',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    message_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    session_data JSONB -- Additional metadata
);

-- Indexes for efficient querying
CREATE INDEX chat_sessions_paper_id_idx ON chat_sessions(paper_id);
CREATE INDEX chat_sessions_last_message_idx ON chat_sessions(last_message_at DESC);
CREATE INDEX chat_sessions_user_paper_idx ON chat_sessions(user_id, paper_id);
```

#### 5. Chat Messages Table
```sql
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'ASSISTANT')),
    content TEXT NOT NULL,
    metadata JSONB, -- Context information, AI model used, etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX chat_messages_session_id_idx ON chat_messages(session_id);
CREATE INDEX chat_messages_created_at_idx ON chat_messages(created_at);
```

### Relationships

```sql
-- Paper-Author many-to-many
CREATE TABLE paper_authors (
    paper_id UUID REFERENCES papers(id) ON DELETE CASCADE,
    author_id UUID REFERENCES authors(id) ON DELETE CASCADE,
    position INTEGER, -- Author order
    affiliation VARCHAR(500), -- Affiliation at time of publication
    PRIMARY KEY (paper_id, author_id)
);

-- Paper Figures
CREATE TABLE paper_figures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_id UUID NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
    caption TEXT,
    figure_type VARCHAR(50), -- 'figure', 'table', 'equation'
    position INTEGER,
    image_url VARCHAR(1000),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### Chat Session Management

#### Create Chat Session
```http
POST /api/papers/{paperId}/chat/sessions
Content-Type: application/json
Authorization: Bearer {token}

{
  "initialMessage": "What is the main contribution of this paper?",
  "sessionTitle": "Main Contributions Discussion",
  "selectedText": "optional selected text from paper",
  "selectionContext": {
    "from": 100,
    "to": 200,
    "pageNumber": 1,
    "sectionTitle": "Introduction"
  }
}
```

**Response:**
```json
{
  "sessionId": "123e4567-e89b-12d3-a456-426614174000",
  "paperId": "987fcdeb-51a2-43d8-b679-123456789abc",
  "title": "Main Contributions Discussion",
  "createdAt": "2025-09-08T10:30:00Z",
  "lastMessageAt": "2025-09-08T10:30:05Z",
  "messageCount": 2,
  "isActive": true,
  "lastMessagePreview": "The main contribution of this paper is..."
}
```

#### Continue Chat Session
```http
POST /api/papers/{paperId}/chat/sessions/{sessionId}/messages
Content-Type: application/json
Authorization: Bearer {token}

{
  "message": "Can you explain the methodology in more detail?",
  "selectedText": "optional selected text",
  "selectionContext": {
    "from": 500,
    "to": 600,
    "pageNumber": 3,
    "sectionTitle": "Methodology"
  }
}
```

**Response:**
```json
{
  "sessionId": "123e4567-e89b-12d3-a456-426614174000",
  "response": "The methodology section describes a comprehensive approach...",
  "context": {
    "sectionsUsed": ["Methodology", "Experimental Setup"],
    "figuresReferenced": ["Figure 1", "Table 2"],
    "confidenceScore": 0.95,
    "contentSources": ["section_1", "section_3"]
  },
  "timestamp": "2025-09-08T10:35:00Z",
  "success": true
}
```

#### Get Chat Sessions
```http
GET /api/papers/{paperId}/chat/sessions
Authorization: Bearer {token}
```

**Response:**
```json
[
  {
    "sessionId": "123e4567-e89b-12d3-a456-426614174000",
    "paperId": "987fcdeb-51a2-43d8-b679-123456789abc",
    "title": "Main Contributions Discussion",
    "createdAt": "2025-09-08T10:30:00Z",
    "lastMessageAt": "2025-09-08T10:35:00Z",
    "messageCount": 4,
    "isActive": true,
    "isCurrent": false
  }
]
```

#### Get Chat Session History
```http
GET /api/papers/{paperId}/chat/sessions/{sessionId}/messages
Authorization: Bearer {token}
```

**Response:**
```json
{
  "sessionId": "123e4567-e89b-12d3-a456-426614174000",
  "title": "Main Contributions Discussion",
  "messages": [
    {
      "id": "msg-001",
      "role": "USER",
      "content": "What is the main contribution of this paper?",
      "timestamp": "2025-09-08T10:30:00Z"
    },
    {
      "id": "msg-002",
      "role": "ASSISTANT",
      "content": "The main contribution of this paper is...",
      "timestamp": "2025-09-08T10:30:05Z"
    }
  ]
}
```

### Paper Management

#### Check Paper Chat Readiness
```http
GET /api/papers/{paperId}/chat/readiness
Authorization: Bearer {token}
```

**Response:**
```json
{
  "paperId": "987fcdeb-51a2-43d8-b679-123456789abc",
  "isReady": true,
  "extractionStatus": "COMPLETED",
  "extractionCompletedAt": "2025-09-08T09:15:00Z",
  "sectionsCount": 8,
  "authorsCount": 5
}
```

#### Extract Paper for Chat
```http
POST /api/papers/{paperId}/extract
Authorization: Bearer {token}
```

**Response:**
```json
{
  "paperId": "987fcdeb-51a2-43d8-b679-123456789abc",
  "status": "STARTED",
  "estimatedDuration": "60 seconds",
  "jobId": "extract-job-12345"
}
```

## Deployment & Configuration

### Docker Compose Setup

#### Services Configuration
```yaml
# docker-compose.yml
version: '3.8'

services:
  # API Gateway
  api-gateway:
    build: ./Microservices/api-gateway
    ports:
      - "8989:8989"
    environment:
      - EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE=http://service-registry:8761/eureka
    depends_on:
      - service-registry

  # Project Service
  project-service:
    build: ./Microservices/project-service
    ports:
      - "8083:8083"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://project-db:5432/project_db
      - SPRING_DATASOURCE_USERNAME=admin
      - SPRING_DATASOURCE_PASSWORD=password
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      - project-db
      - service-registry

  # PDF Extractor Service
  extractor:
    build: ./AI-Agents/extractor
    ports:
      - "8002:8002"
    environment:
      - GROBID_URL=http://grobid:8070
      - DATABASE_URL=postgresql://admin:password@project-db:5432/project_db
    depends_on:
      - grobid
      - project-db

  # GROBID Service
  grobid:
    build: ./Docker/Dockerfile.grobid
    ports:
      - "8070:8070"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8070/api/isalive"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Frontend
  frontend:
    build: ./Frontend
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8989
    depends_on:
      - api-gateway

  # Database
  project-db:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: project_db
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password
    volumes:
      - project_db_data:/var/lib/postgresql/data
    ports:
      - "5435:5432"

volumes:
  project_db_data:
```

### Environment Configuration

#### Backend (.env)
```env
# Database
DATABASE_URL=jdbc:postgresql://localhost:5435/project_db
DATABASE_USERNAME=admin
DATABASE_PASSWORD=password

# AI Service
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-4-turbo-preview
OPENAI_MAX_TOKENS=1000
OPENAI_TEMPERATURE=0.3

# GROBID
GROBID_URL=http://localhost:8070

# Redis
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@localhost:5672
RABBITMQ_EXCHANGE=paper.exchange
RABBITMQ_QUEUE=paper.extraction.queue

# Service Registry
EUREKA_SERVER_URL=http://localhost:8761/eureka
```

#### Frontend (.env.local)
```env
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:8989
NEXT_PUBLIC_ENVIRONMENT=development

# Authentication (Future)
NEXT_PUBLIC_AUTH_DOMAIN=your-auth-domain
NEXT_PUBLIC_AUTH_CLIENT_ID=your-auth-client-id

# Features
NEXT_PUBLIC_ENABLE_CHAT=true
NEXT_PUBLIC_ENABLE_SEARCH=true
NEXT_PUBLIC_ENABLE_EXTRACTION=true
```

### Startup Sequence

1. **Infrastructure Services**
   ```bash
   # Start databases, Redis, RabbitMQ
   docker-compose up -d project-db user-db notification-db redis rabbitmq
   ```

2. **Core Services**
   ```bash
   # Start service registry first
   docker-compose up -d service-registry
   sleep 30
   
   # Start other services
   docker-compose up -d api-gateway project-service user-service notification-service
   ```

3. **AI Services**
   ```bash
   # Start GROBID and extractor
   docker-compose up -d grobid
   sleep 60  # Wait for GROBID to be ready
   docker-compose up -d extractor paper-search
   ```

4. **Frontend**
   ```bash
   # Start frontend last
   docker-compose up -d frontend
   ```

### Health Checks

```bash
# Check all services
curl http://localhost:8989/actuator/health  # API Gateway
curl http://localhost:8083/actuator/health  # Project Service
curl http://localhost:8002/health          # PDF Extractor
curl http://localhost:8070/api/isalive     # GROBID
curl http://localhost:3000                 # Frontend
```

## Troubleshooting

### Common Issues

#### 1. Chat Returns "No Response Received"

**Symptoms:**
- Welcome message displays correctly
- User messages sent but no AI response
- Frontend shows "No response received"

**Causes & Solutions:**

1. **Response Format Mismatch**
   ```javascript
   // Check ChatResponse interface includes title field
   export interface ChatResponse {
       sessionId: string;
       response: string;
       title?: string;  // Must be present
       timestamp: string;
       success: boolean;
   }
   ```

2. **Backend Session Creation**
   ```java
   // Ensure PaperContextChatController returns proper response
   public ResponseEntity<ChatSessionResponse> createChatSession(...) {
       ChatSessionResponse response = chatSessionService.createSession(paperId, request);
       return ResponseEntity.ok(response);  // Must return 200 OK
   }
   ```

3. **Frontend Conversion**
   ```typescript
   // In createChatSession function
   const chatResponse: ChatResponse = {
       sessionId: sessionResult.sessionId,
       response: sessionResult.lastMessagePreview || "Session created successfully",
       title: sessionResult.title,  // Include title
       timestamp: sessionResult.lastMessageAt || sessionResult.createdAt,
       success: true,
   };
   ```

#### 2. Author Names Show as Java Object References

**Symptoms:**
```
org.solace.scholar_ai.project_service.model.author.Author@60f87e9c
```

**Solution:**
Add `toString()` method to Author entity:
```java
@Override
public String toString() {
    return name != null ? name : "Unknown Author";
}
```

#### 3. Chat Sessions Not Sorted Properly

**Symptoms:**
- Older sessions appear before newer ones
- Invalid sessions mixed with valid ones

**Solution:**
```typescript
const sortedSessions = sessions.sort((a, b) => {
    // Invalid sessions go to bottom
    const aValid = a.lastMessageAt && a.title;
    const bValid = b.lastMessageAt && b.title;
    
    if (!aValid && bValid) return 1;
    if (aValid && !bValid) return -1;
    if (!aValid && !bValid) return 0;
    
    // Sort by latest activity
    return new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime();
});
```

#### 4. GROBID Extraction Fails

**Symptoms:**
- Papers stuck in "PENDING" extraction status
- 500 errors from extractor service

**Debugging:**
```bash
# Check GROBID health
curl http://localhost:8070/api/isalive

# Check GROBID logs
docker logs pdf_extractor_grobid

# Test direct GROBID call
curl -X POST http://localhost:8070/api/processFulltextDocument \
  -F "input=@test.pdf" \
  -F "consolidateHeader=1"
```

#### 5. Database Connection Issues

**Symptoms:**
- Services fail to start
- Connection timeout errors

**Solutions:**
```bash
# Check database status
docker-compose ps project-db

# Check database logs
docker logs project-db

# Test connection
psql -h localhost -p 5435 -U admin -d project_db
```

### Performance Optimization

#### 1. Database Indexes
```sql
-- Essential indexes for chat performance
CREATE INDEX CONCURRENTLY chat_sessions_paper_active_idx 
ON chat_sessions(paper_id, is_active, last_message_at DESC);

CREATE INDEX CONCURRENTLY chat_messages_session_created_idx 
ON chat_messages(session_id, created_at);

CREATE INDEX CONCURRENTLY paper_sections_search_idx 
ON paper_sections USING gin(to_tsvector('english', title || ' ' || content));
```

#### 2. Redis Caching
```java
@Cacheable(value = "paper-context", key = "#paperId")
public String getPaperContext(UUID paperId) {
    // Expensive operation to build context
}

@CacheEvict(value = "paper-context", key = "#paperId")
public void invalidatePaperContext(UUID paperId) {
    // Called when paper is updated
}
```

#### 3. Connection Pooling
```yaml
# application.yml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 300000
      max-lifetime: 1200000
      connection-timeout: 20000
```

## Future Enhancements

### Planned Features

#### 1. Enhanced AI Capabilities

**Multi-Model Support**
- Claude, Gemini integration
- Model selection per conversation
- Performance comparison metrics

**Advanced Context Processing**
- Vector embeddings for semantic search
- Cross-paper references
- Citation following

#### 2. Collaboration Features

**Shared Sessions**
- Multi-user chat sessions
- Real-time collaboration
- Comment threads

**Team Workspaces**
- Shared paper collections
- Team chat histories
- Permission management

#### 3. Advanced Analytics

**Usage Metrics**
- Most discussed papers
- Popular question types
- User engagement patterns

**Quality Metrics**
- Response accuracy tracking
- User satisfaction ratings
- Content relevance scoring

#### 4. Mobile Application

**React Native App**
- Native mobile experience
- Offline reading capability
- Push notifications

#### 5. API Enhancements

**GraphQL Integration**
- Flexible query capabilities
- Reduced API calls
- Better frontend optimization

**Webhook Support**
- Real-time notifications
- Third-party integrations
- Event-driven architecture

### Architecture Evolution

#### Microservices Expansion
```
Current: Monolithic Project Service
Future: Specialized Services
├── Paper Management Service
├── Chat Session Service
├── AI Processing Service
├── User Management Service
└── Analytics Service
```

#### Event-Driven Architecture
```
Event Bus (Apache Kafka)
├── Paper.Uploaded
├── Extraction.Completed
├── Chat.SessionCreated
├── Chat.MessageSent
└── AI.ResponseGenerated
```

#### Kubernetes Deployment
```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chat-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: chat-service
  template:
    metadata:
      labels:
        app: chat-service
    spec:
      containers:
      - name: chat-service
        image: scholarai/chat-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
```

## Conclusion

The ScholarAI session-based chat system provides a robust, scalable foundation for intelligent academic paper analysis. The modular architecture supports future enhancements while maintaining stability and performance.

Key strengths:
- **Scalable Architecture**: Microservices design supports horizontal scaling
- **Intelligent Processing**: AI-powered contextual responses with paper-specific knowledge
- **User Experience**: ChatGPT-like interface with session management
- **Robust Extraction**: GROBID-based PDF processing with high accuracy
- **Comprehensive API**: RESTful endpoints with proper error handling

This documentation serves as a complete reference for understanding, maintaining, and extending the chat system functionality.

---

**Last Updated**: September 8, 2025
**Version**: 1.0
**Authors**: ScholarAI Development Team