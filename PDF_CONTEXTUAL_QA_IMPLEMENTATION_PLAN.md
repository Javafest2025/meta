# PDF Contextual Q&A Implementation Plan
**ScholarAI Meta Repository - Critical Feature Implementation**

> **IMPORTANT**: This document provides a comprehensive analysis for implementing PDF-based contextual Q&A functionality where the extracted PDF content serves as the context for AI chat interactions.

---

## 🎯 **Goal & Objective**

### **Primary Goal**
Implement a contextual Q&A system where users can ask questions about any PDF paper through the AI chat panel, and the AI responds using the extracted PDF content as context.

### **User Journey**
1. User clicks "View PDF" from library (or any section)
2. PDF opens in the viewer with AI chat panel in top-right
3. System checks if PDF is already extracted in the database
4. **If NOT extracted**: Shows progress bar → Triggers extraction → Waits for completion
5. **If extracted**: Chat is immediately available
6. User asks questions in AI chat → AI responds using extracted content as context

### **Key Requirements**
- ✅ **Extraction Check**: Query database to verify extraction status
- ✅ **Progress Indication**: Real-time extraction progress updates
- ✅ **Context Integration**: Use extracted JSON content for AI responses
- ✅ **Seamless UX**: No manual intervention required
- ✅ **Error Handling**: Graceful fallbacks if extraction fails

---

## 📊 **Database Schema Analysis**

### **Papers Table Structure**
```sql
-- Core paper entity with extraction tracking
CREATE TABLE papers (
    id UUID PRIMARY KEY,
    correlation_id VARCHAR(100) NOT NULL,
    
    -- PDF Information
    pdf_content_url VARCHAR(500),    -- B2 storage URL
    pdf_url VARCHAR(500),           -- Original PDF URL
    
    -- Extraction Status Fields
    is_extracted BOOLEAN DEFAULT FALSE,
    extraction_status VARCHAR(50),   -- PENDING, PROCESSING, COMPLETED, FAILED
    extraction_job_id VARCHAR(100),
    extraction_started_at TIMESTAMP,
    extraction_completed_at TIMESTAMP,
    extraction_error TEXT,
    extraction_coverage DOUBLE,     -- 0-100%
    
    -- Other fields...
    title VARCHAR(500) NOT NULL,
    abstract_text TEXT,
    publication_date DATE,
    -- ... remaining fields
);
```

### **Paper Extraction Table Structure**
```sql
-- Detailed extraction results
CREATE TABLE paper_extractions (
    id UUID PRIMARY KEY,
    paper_id UUID REFERENCES papers(id),
    extraction_id VARCHAR(100) UNIQUE,
    
    -- Extraction Metadata
    extraction_timestamp TIMESTAMP,
    processing_time DOUBLE,
    extraction_coverage DOUBLE,
    confidence_scores TEXT,         -- JSON object
    
    -- Content Structure
    page_count INTEGER,
    language VARCHAR(10),
    
    -- Related extracted content
    -- sections: OneToMany ExtractedSection
    -- figures: OneToMany ExtractedFigure  
    -- tables: OneToMany ExtractedTable
    -- equations: OneToMany ExtractedEquation
    -- references: OneToMany ExtractedReference
    -- entities: OneToMany ExtractedEntity
);
```

### **Database Tables We Need to Know**
1. **`papers`** - Main paper entity with extraction status
2. **`paper_extractions`** - Detailed extraction results and metadata
3. **`extracted_sections`** - Text content organized by sections
4. **`extracted_figures`** - Figure descriptions and metadata
5. **`extracted_tables`** - Table content and structure
6. **`extracted_equations`** - Mathematical equations and formulas
7. **`extracted_references`** - Bibliography and citations
8. **`extracted_entities`** - Named entities (authors, institutions, etc.)

---

## 🔧 **Key Files to Modify**

### **Frontend Files**
```
📁 Frontend/
├── 📁 components/
│   ├── 📁 document/
│   │   └── 📄 PdfViewer.tsx                    # Add extraction check & progress
│   ├── 📁 chat/
│   │   ├── 📄 ChatContainer.tsx               # Add extraction integration
│   │   └── 📄 ChatComposer.tsx                # Handle extraction state
│   └── 📁 library/
│       └── 📄 PdfViewerModal.tsx              # Add extraction workflow
├── 📁 lib/
│   └── 📁 api/
│       ├── 📄 chat.ts                         # Update chat with extraction
│       ├── 📄 extraction.ts                   # NEW: Extraction API calls
│       └── 📄 project-service.ts              # Paper extraction queries
└── 📁 types/
    ├── 📄 extraction.ts                       # NEW: Extraction types
    └── 📄 chat.ts                             # Update chat types
```

### **Backend Files**
```
📁 Microservices/project-service/
├── 📁 src/main/java/org/solace/scholar_ai/project_service/
│   ├── 📁 controller/
│   │   ├── 📁 extraction/
│   │   │   └── 📄 ExtractionController.java    # EXISTS: Trigger extraction
│   │   └── 📁 chat/
│   │       └── 📄 PaperChatController.java     # NEW: Paper-based chat
│   ├── 📁 service/
│   │   ├── 📁 extraction/
│   │   │   ├── 📄 ExtractionService.java       # EXISTS: Orchestrate extraction
│   │   │   └── 📄 ExtractionStatusService.java # NEW: Check extraction status
│   │   └── 📁 chat/
│   │       └── 📄 PaperContextChatService.java # NEW: AI chat with PDF context
│   ├── 📁 repository/
│   │   └── 📁 extraction/
│   │       └── 📄 PaperExtractionRepository.java # EXISTS: Query extraction data
│   └── 📁 dto/
│       ├── 📁 extraction/
│       │   ├── 📄 ExtractionStatusResponse.java  # NEW: Status check response
│       │   └── 📄 ExtractionProgressResponse.java # NEW: Progress updates
│       └── 📁 chat/
│           ├── 📄 PaperChatRequest.java          # NEW: Chat request with paper
│           └── 📄 PaperChatResponse.java         # NEW: Chat response with context
```

### **AI-Agents/extractor Files**
```
📁 AI-Agents/extractor/
├── 📁 app/
│   ├── 📄 main.py                              # EXISTS: FastAPI endpoints
│   ├── 📁 services/
│   │   ├── 📄 pipeline.py                      # EXISTS: Extraction pipeline
│   │   ├── 📄 extraction_handler.py           # EXISTS: RabbitMQ handler
│   │   └── 📄 progress_service.py             # NEW: Progress tracking
│   └── 📁 models/
│       └── 📄 schemas.py                       # EXISTS: Extraction schemas
```

---

## 🌐 **API Endpoints**

### **Extraction Management** *(Project Service)*
```http
# Check if paper is extracted
GET /api/v1/papers/{paperId}/extraction/status
Response: {
  "isExtracted": boolean,
  "status": "PENDING|PROCESSING|COMPLETED|FAILED",
  "progress": number,        // 0-100
  "extractionId": string,
  "startedAt": timestamp,
  "completedAt": timestamp,
  "error": string
}

# Trigger paper extraction
POST /api/v1/extraction/trigger
Request: {
  "paperId": "uuid",
  "correlationId": "string",
  "priority": "HIGH|NORMAL|LOW"
}
Response: {
  "jobId": "uuid",
  "status": "SUBMITTED",
  "estimatedTime": number,   // seconds
  "message": "string"
}

# Get extraction progress (WebSocket or polling)
GET /api/v1/extraction/{jobId}/progress
Response: {
  "jobId": "uuid",
  "status": "PROCESSING|COMPLETED|FAILED",
  "progress": number,        // 0-100
  "currentStep": "string",
  "timeElapsed": number,
  "timeRemaining": number
}
```

### **Contextual Chat** *(Project Service)*
```http
# Chat with paper using extracted content as context
POST /api/v1/papers/{paperId}/chat
Request: {
  "message": "string",
  "sessionId": "uuid",       // optional
  "sessionTitle": "string",  // optional
  "useFullContext": boolean  // use all extracted content
}
Response: {
  "sessionId": "uuid",
  "response": "string",
  "context": {
    "sectionsUsed": ["section1", "section2"],
    "figuresReferenced": ["fig1"],
    "tablesReferenced": ["table1"],
    "confidenceScore": number
  },
  "timestamp": "datetime",
  "success": boolean
}

# Get paper's extracted content summary
GET /api/v1/papers/{paperId}/extraction/summary
Response: {
  "extractionId": "uuid",
  "contentTypes": ["text", "figures", "tables", "equations"],
  "sectionsCount": number,
  "figuresCount": number,
  "tablesCount": number,
  "pageCount": number,
  "extractionCoverage": number,
  "language": "string"
}
```

### **Extractor Service Endpoints** *(AI-Agents/extractor)*
```http
# Extract PDF from B2 URL (existing)
POST /api/v1/extract-b2
Request: {
  "jobId": "uuid",
  "correlationId": "string", 
  "paperId": "uuid",
  "b2Url": "string",
  "extractionOptions": {
    "extractText": boolean,
    "extractFigures": boolean,
    "extractTables": boolean,
    "extractEquations": boolean,
    "extractReferences": boolean,
    "useOcr": boolean
  }
}

# Get extraction job status (existing)
GET /api/v1/jobs/{jobId}/status
Response: {
  "jobId": "uuid",
  "status": "PROCESSING|COMPLETED|FAILED", 
  "progress": number,
  "result": object          // Full extraction result when completed
}
```

---

## 🔄 **Implementation Workflow**

### **Phase 1: Database & Backend Setup**
1. **✅ Verify database schema** - Ensure papers table has extraction fields
2. **🔧 Create ExtractionStatusService** - Query extraction status from DB
3. **🔧 Create PaperContextChatService** - AI chat using extracted content
4. **🔧 Add extraction status endpoints** - Check if paper is extracted
5. **🔧 Implement contextual chat endpoint** - Chat with paper context

### **Phase 2: Frontend Integration**
1. **🔧 Update PdfViewer component** - Add extraction check on PDF load
2. **🔧 Add progress indication** - Show extraction progress bar
3. **🔧 Update ChatContainer** - Integrate with extraction status
4. **🔧 Add extraction API calls** - Frontend extraction service
5. **🔧 Implement chat with context** - Use extracted content for AI

### **Phase 3: Real-time Updates**
1. **🔧 WebSocket progress updates** - Real-time extraction progress
2. **🔧 RabbitMQ result handling** - Process extraction completion
3. **🔧 Error handling & retries** - Graceful extraction failures
4. **🔧 Performance optimization** - Cache extraction results

### **Phase 4: Testing & Optimization**
1. **🧪 End-to-end testing** - Complete user journey
2. **⚡ Performance tuning** - Optimize extraction & chat
3. **🐛 Bug fixes & polish** - Address edge cases
4. **📚 Documentation** - API docs & user guides

---

## 🔍 **Detailed Implementation Process**

### **Step 1: Backend - Extraction Status Service**
```java
// ExtractionStatusService.java
@Service
public class ExtractionStatusService {
    
    public ExtractionStatusDto checkExtractionStatus(UUID paperId) {
        Paper paper = paperRepository.findById(paperId)
            .orElseThrow(() -> new PaperNotFoundException(paperId));
            
        return ExtractionStatusDto.builder()
            .isExtracted(paper.getIsExtracted())
            .status(paper.getExtractionStatus())
            .progress(calculateProgress(paper))
            .extractionId(paper.getExtractionJobId())
            .startedAt(paper.getExtractionStartedAt())
            .completedAt(paper.getExtractionCompletedAt())
            .error(paper.getExtractionError())
            .build();
    }
    
    private Double calculateProgress(Paper paper) {
        // Calculate based on extraction status and timestamps
        if (paper.getExtractionStatus() == "COMPLETED") return 100.0;
        if (paper.getExtractionStatus() == "FAILED") return 0.0;
        // Estimate progress based on time elapsed...
        return paper.getExtractionCoverage();
    }
}
```

### **Step 2: Backend - Paper Context Chat Service**
```java
// PaperContextChatService.java  
@Service
public class PaperContextChatService {
    
    @Autowired
    private GeminiService geminiService;
    
    @Autowired 
    private PaperExtractionRepository extractionRepository;
    
    public PaperChatResponse chatWithPaper(UUID paperId, PaperChatRequest request) {
        // 1. Get paper and verify extraction
        Paper paper = paperRepository.findById(paperId)
            .orElseThrow(() -> new PaperNotFoundException(paperId));
            
        if (!paper.getIsExtracted()) {
            throw new PaperNotExtractedException(paperId);
        }
        
        // 2. Retrieve extracted content
        PaperExtraction extraction = extractionRepository.findByPaperId(paperId)
            .orElseThrow(() -> new ExtractionNotFoundException(paperId));
        
        // 3. Build context from extracted content
        String context = buildChatContext(extraction);
        
        // 4. Send to AI with context
        String aiResponse = geminiService.chatWithContext(
            request.getMessage(), 
            context,
            request.getSessionId()
        );
        
        // 5. Return response with metadata
        return PaperChatResponse.builder()
            .sessionId(request.getSessionId())
            .response(aiResponse)
            .context(buildContextMetadata(extraction))
            .timestamp(Instant.now())
            .success(true)
            .build();
    }
    
    private String buildChatContext(PaperExtraction extraction) {
        StringBuilder context = new StringBuilder();
        
        // Add paper metadata
        context.append("Paper: ").append(extraction.getTitle()).append("\\n");
        context.append("Abstract: ").append(extraction.getAbstractText()).append("\\n\\n");
        
        // Add sections
        extraction.getSections().forEach(section -> {
            context.append("Section: ").append(section.getTitle()).append("\\n");
            context.append(section.getContent()).append("\\n\\n");
        });
        
        // Add figures descriptions
        extraction.getFigures().forEach(figure -> {
            context.append("Figure ").append(figure.getFigureNumber())
                   .append(": ").append(figure.getCaption()).append("\\n");
        });
        
        // Add tables content
        extraction.getTables().forEach(table -> {
            context.append("Table ").append(table.getTableNumber())
                   .append(": ").append(table.getCaption()).append("\\n")
                   .append(table.getContent()).append("\\n\\n");
        });
        
        return context.toString();
    }
}
```

### **Step 3: Frontend - PDF Viewer with Extraction**
```typescript
// PdfViewer.tsx updates
const PDFViewer: React.FC<Props> = ({ documentUrl, documentName, paperId }) => {
  const [extractionStatus, setExtractionStatus] = useState<ExtractionStatus | null>(null);
  const [isExtracting, setIsExtracting] = useState(false);
  const [extractionProgress, setExtractionProgress] = useState(0);

  useEffect(() => {
    if (paperId) {
      checkExtractionStatus();
    }
  }, [paperId]);

  const checkExtractionStatus = async () => {
    try {
      const status = await getExtractionStatus(paperId);
      setExtractionStatus(status);
      
      if (!status.isExtracted && status.status !== 'FAILED') {
        // Trigger extraction if not extracted
        await triggerExtraction();
      }
    } catch (error) {
      console.error('Failed to check extraction status:', error);
    }
  };

  const triggerExtraction = async () => {
    try {
      setIsExtracting(true);
      const response = await triggerPaperExtraction(paperId);
      
      // Poll for progress updates
      const progressInterval = setInterval(async () => {
        const progress = await getExtractionProgress(response.jobId);
        setExtractionProgress(progress.progress);
        
        if (progress.status === 'COMPLETED') {
          clearInterval(progressInterval);
          setIsExtracting(false);
          setExtractionStatus(prev => ({ ...prev, isExtracted: true }));
        } else if (progress.status === 'FAILED') {
          clearInterval(progressInterval);
          setIsExtracting(false);
          // Handle extraction failure
        }
      }, 2000);
      
    } catch (error) {
      setIsExtracting(false);
      console.error('Failed to trigger extraction:', error);
    }
  };

  return (
    <div className="relative h-full w-full">
      {/* Extraction Progress Overlay */}
      {isExtracting && (
        <div className="absolute inset-0 bg-black/50 z-50 flex items-center justify-center">
          <div className="bg-white p-6 rounded-lg">
            <h3>Extracting PDF Content...</h3>
            <Progress value={extractionProgress} className="mt-2" />
            <p className="text-sm text-gray-600 mt-2">
              This enables AI chat functionality
            </p>
          </div>
        </div>
      )}
      
      {/* PDF Viewer */}
      <Worker workerUrl="/pdfjs/pdf.worker.min.js">
        <Viewer fileUrl={processedPdfUrl} plugins={[...plugins]} />
      </Worker>
      
      {/* AI Chat Panel */}
      {showChatDrawer && (
        <ChatContainer 
          paperId={paperId}
          isChatReady={extractionStatus?.isExtracted}
          onClose={() => setShowChatDrawer(false)}
        />
      )}
    </div>
  );
};
```

### **Step 4: Frontend - Chat with Extraction Context**
```typescript
// ChatContainer.tsx updates
export function ChatContainer({ paperId, isChatReady, onClose }: ChatContainerProps) {
  const [extractionSummary, setExtractionSummary] = useState<ExtractionSummary | null>(null);

  useEffect(() => {
    if (paperId && isChatReady) {
      loadExtractionSummary();
    }
  }, [paperId, isChatReady]);

  const loadExtractionSummary = async () => {
    try {
      const summary = await getExtractionSummary(paperId);
      setExtractionSummary(summary);
    } catch (error) {
      console.error('Failed to load extraction summary:', error);
    }
  };

  const handleSendMessage = async (content: string) => {
    if (!paperId || !isChatReady) return;

    setIsLoading(true);
    try {
      const response = await chatWithPaper(paperId, content, sessionId);
      
      // Add user message
      const userMessage: Message = {
        id: generateId(),
        role: 'user',
        content,
        timestamp: new Date().toISOString()
      };

      // Add AI response with context info
      const assistantMessage: Message = {
        id: generateId(),
        role: 'assistant', 
        content: response.response,
        timestamp: response.timestamp,
        context: response.context // Include context metadata
      };

      setMessages(prev => [...prev, userMessage, assistantMessage]);
    } catch (error) {
      console.error('Chat error:', error);
      // Handle chat error
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="chat-container">
      {/* Context Information */}
      {extractionSummary && (
        <div className="p-3 bg-blue-50 border-b">
          <p className="text-xs text-blue-600">
            💡 Chatting with: {extractionSummary.sectionsCount} sections, 
            {extractionSummary.figuresCount} figures, {extractionSummary.tablesCount} tables
          </p>
        </div>
      )}
      
      {/* Chat Messages */}
      <div className="messages">
        {messages.map(message => (
          <ChatMessage 
            key={message.id} 
            message={message}
            showContext={message.role === 'assistant' && message.context}
          />
        ))}
      </div>
      
      {/* Chat Input */}
      <ChatComposer 
        onSendMessage={handleSendMessage}
        disabled={!isChatReady || isLoading}
        placeholder={
          isChatReady 
            ? "Ask about this paper..." 
            : "Extracting content for AI chat..."
        }
      />
    </div>
  );
}
```

---

## 🚀 **Files for Deep Research**

### **For Understanding Current Architecture**
1. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/model/paper/Paper.java`**
2. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/model/extraction/PaperExtraction.java`**
3. **`AI-Agents/extractor/app/main.py`**
4. **`AI-Agents/extractor/app/services/pipeline.py`**
5. **`Frontend/components/document/PdfViewer.tsx`**
6. **`Frontend/components/chat/ChatContainer.tsx`**

### **For Database Integration**
1. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/repository/paper/PaperRepository.java`**
2. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/repository/extraction/PaperExtractionRepository.java`**
3. **`Microservices/project-service/src/main/resources/db/migration/V4__add_latex_context_column_to_papers.sql`**

### **For API Development**
1. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/controller/extraction/ExtractionController.java`**
2. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/service/extraction/ExtractionService.java`**
3. **`Frontend/lib/api/chat.ts`**
4. **`Frontend/lib/api/project-service.ts`**

### **For AI Integration**
1. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/config/GeminiConfig.java`**
2. **`AI-Agents/extractor/app/services/extraction_handler.py`**
3. **`AI-Agents/extractor/app/services/messaging/handlers.py`**

### **For RabbitMQ & Progress Tracking**
1. **`Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/messaging/`**
2. **`AI-Agents/extractor/app/services/messaging/`**
3. **`AI-Agents/extractor/app/services/background_worker.py`**

---

## ⚠️ **Critical Questions for LLM Research**

1. **How does the current RabbitMQ communication work between project-service and extractor?**
2. **What is the exact format of the extraction JSON results stored in the database?**
3. **How is the Gemini AI service currently configured and integrated?**
4. **What are the current authentication/authorization patterns for API calls?**
5. **How does the current chat functionality work without extraction context?**
6. **What error handling patterns are used across the microservices?**
7. **How are database transactions managed for extraction operations?**
8. **What caching strategies are in place for extracted content?**

---

## 📋 **Implementation Checklist**

### **Backend Tasks**
- [ ] Create `ExtractionStatusService` for checking extraction status
- [ ] Create `PaperContextChatService` for AI chat with PDF context
- [ ] Add extraction status endpoints (`GET /papers/{id}/extraction/status`)
- [ ] Add contextual chat endpoint (`POST /papers/{id}/chat`)
- [ ] Implement progress tracking for extraction jobs
- [ ] Add WebSocket support for real-time progress updates
- [ ] Create DTOs for extraction status and chat context
- [ ] Update repository methods for extraction queries

### **Frontend Tasks**
- [ ] Update `PdfViewer.tsx` to check extraction status on load
- [ ] Add extraction progress indicator component
- [ ] Update `ChatContainer.tsx` to integrate with extraction
- [ ] Create extraction API service (`lib/api/extraction.ts`)
- [ ] Add extraction status types and interfaces
- [ ] Implement real-time progress updates (WebSocket/polling)
- [ ] Add error handling for extraction failures
- [ ] Update chat to display context information

### **Integration Tasks**
- [ ] Test end-to-end workflow (PDF → extraction → chat)
- [ ] Implement proper error handling and user feedback
- [ ] Add performance monitoring for extraction times
- [ ] Create user documentation for the feature
- [ ] Add unit and integration tests
- [ ] Performance optimization for large PDFs
- [ ] Cache frequently accessed extraction results

---

**🎯 This document provides the complete roadmap for implementing PDF contextual Q&A. The LLM should focus on the files listed in the "Files for Deep Research" section to understand the current implementation patterns and create a robust, scalable solution.**
