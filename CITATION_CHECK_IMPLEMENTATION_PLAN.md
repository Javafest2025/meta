# Citation Check Implementation Plan

## Project Overview
Implementing a complete citation checking system in the LaTeX AI Assistant that analyzes LaTeX documents for citation issues and provides real-time progress feedback to users.

## Main Target
**Enable users to click "Citation Check" button in the LaTeX editor and see:**
1. ✅ Successful API call with proper job ID
2. 🔄 Real-time progress bar with status updates 
3. 📊 Citation analysis results display
4. 🔍 Detection of missing citations, weak citations, and citation formatting issues

## Current Status Summary

### ✅ **COMPLETED** 
- **Backend Citation API**: Fully functional `/api/citations/jobs` endpoint
- **Database Integration**: PostgreSQL with proper JSONB handling and enum converters
- **DTO Mapping Fix**: Frontend now sends correct field format to backend
- **Core Citation Processing**: Creates citation checks and detects issues successfully

### 🔄 **IN PROGRESS**
- **Response Field Mapping**: Backend returns `{currentStep, progressPercent}` but frontend expects `{step, progressPct}`
- **Frontend Syntax Errors**: Build issues preventing clean deployment

### ⏳ **PENDING**
- **Progress Bar UI**: Complete implementation with polling
- **Results Display**: Show citation issues in the interface
- **Error Handling**: User-friendly error messages

## Technical Architecture

### Pipeline Flow
```
Frontend (AIChatPanel.tsx) 
    ↓ handleCitationCheck()
API Layer (latex-service.ts)
    ↓ POST /api/citations/jobs  
Backend (CitationController → CitationCheckService)
    ↓ Database (PostgreSQL)
Polling (getCitationJob) 
    ↓ GET /api/citations/jobs/{jobId}
UI Updates (Progress Bar + Results)
```

### Key Components
- **Frontend**: `components/latex/AIChatPanel.tsx`
- **API Service**: `lib/api/latex-service.ts` 
- **Backend Controller**: `CitationController.java`
- **Service Layer**: `CitationCheckService.java`
- **Database Entities**: `CitationCheck`, `CitationIssue`, `CitationEvidence`

## Immediate Next Steps

### **Step 1: Fix Response Field Mapping** ⭐ HIGH PRIORITY
**Issue**: Backend API returns field names that don't match frontend expectations

**Backend Response**:
```json
{
  "id": "uuid",
  "currentStep": "DONE", 
  "progressPercent": 100
}
```

**Frontend Expects**:
```json
{
  "jobId": "uuid",
  "step": "DONE",
  "progressPct": 100  
}
```

**Solution Options**:
1. Update backend DTO to match frontend expectations
2. Fix frontend polling to handle backend field names
3. Add response mapping in API service layer

### **Step 2: Fix Frontend Syntax Errors** ⭐ HIGH PRIORITY
**Issue**: Return statement structure problems in AIChatPanel.tsx around line 1218

**Current Error**:
```
Return statement is not allowed here
```

**Need to Fix**:
- Function structure around renderMessage return
- Main component return statement alignment
- Proper TypeScript/React component syntax

### **Step 3: Complete Progress Polling Implementation** 🎯 CORE FEATURE
**Components to Implement**:
- Start citation check with UI feedback
- Poll job status every 2 seconds
- Update progress bar (0-100%)
- Display status messages ("Parsing LaTeX document...", "Searching for evidence...", etc.)
- Handle completion and error states

### **Step 4: Results Display** 📊 USER EXPERIENCE
**Show Citation Issues**:
- List detected citation problems
- Highlight problematic text sections
- Suggest citation fixes
- Allow users to mark issues as resolved

## File Locations

### Frontend Files
- `Frontend/components/latex/AIChatPanel.tsx` - Main UI component
- `Frontend/lib/api/latex-service.ts` - API service layer
- `Frontend/types/citations.ts` - TypeScript interfaces

### Backend Files  
- `Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/controller/citation/CitationController.java`
- `Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/service/citation/CitationCheckService.java`
- `Microservices/project-service/src/main/java/org/solace/scholar_ai/project_service/dto/citation/CitationCheckResponseDto.java`

## Testing Strategy

### Manual Testing Flow
1. Open LaTeX editor with document containing citation issues
2. Click "Advanced AI Tools" → "Citation Check"  
3. Verify console shows proper job ID (not "undefined")
4. Watch progress bar advance with status updates
5. See citation issues displayed when complete

### Test Document
Use `temp_clean.tex` which contains intentional citation issues:
- Missing citations for claims
- Dangling reference keys
- Incorrect citation metadata

## Success Criteria

### Phase 1 (Basic Functionality)
- ✅ Citation check button starts job successfully
- ✅ Console shows proper job ID
- ✅ Backend processes citation analysis
- ✅ Basic API integration working

### Phase 2 (Progress Tracking)
- 🔄 Progress bar shows during processing
- 🔄 Status messages update in real-time
- 🔄 Completion state handled properly

### Phase 3 (User Experience)  
- 📊 Citation issues displayed clearly
- 🎯 User can interact with results
- ✨ Error handling and edge cases covered

## Expected User Experience

1. **User clicks "Citation Check"** → Button becomes disabled, progress bar appears
2. **Processing starts** → "Parsing LaTeX document..." (10%)
3. **Analysis phase** → "Searching for supporting evidence..." (50%) 
4. **Completion** → "Citation check completed!" (100%)
5. **Results** → List of citation issues with suggestions

## Development Priority
1. **Fix response mapping** (blocks progress display)
2. **Fix syntax errors** (blocks clean deployment) 
3. **Complete progress UI** (core user experience)
4. **Add results display** (complete feature)

---

**Last Updated**: September 17, 2025
**Status**: Core API working, UI integration in progress
**Next Action**: Fix response field mapping for progress polling