# PDF Extraction Database Schema Documentation

## Overview

This document provides a comprehensive overview of the database structure used to store extracted PDF content in the Scholar AI system. The extraction pipeline processes research papers and stores structured data across multiple specialized tables to enable efficient querying and analysis.

## Architecture Overview

The extraction system follows a hierarchical data model:

```
Paper (Base Entity)
└── PaperExtraction (Main Extraction Record)
    ├── ExtractedSection (Document Structure)
    │   └── ExtractedParagraph (Text Content)
    ├── ExtractedFigure (Images & Charts)
    ├── ExtractedTable (Tabular Data)
    ├── ExtractedEquation (Mathematical Formulas)
    ├── ExtractedCodeBlock (Code Snippets)
    ├── ExtractedReference (Bibliography)
    └── ExtractedEntity (Named Entities)
```

## Core Tables

### 1. Papers Table (Base Entity)

The `papers` table contains extraction status and metadata for each paper:

**Extraction-Related Columns:**
- `extraction_status` VARCHAR(50) - Status: PENDING, PROCESSING, COMPLETED, FAILED
- `extraction_job_id` VARCHAR(100) - Unique job identifier from extraction service
- `extraction_started_at` TIMESTAMP - When extraction process began
- `extraction_completed_at` TIMESTAMP - When extraction finished
- `extraction_error` TEXT - Error details if extraction failed
- `extraction_coverage` DOUBLE PRECISION - Extraction completeness (0-100%)

**Relationship:**
- One-to-one with `PaperExtraction` via `paper_id`

### 2. Paper Extractions Table (Main Extraction Record)

**Table:** `paper_extractions`

The central table that holds metadata about the extraction process and links to all extracted content.

**Columns:**
- `id` UUID PRIMARY KEY - Unique extraction record ID
- `paper_id` UUID NOT NULL - Foreign key to papers table
- `extraction_id` VARCHAR(100) UNIQUE - UUID from extractor service
- `pdf_hash` VARCHAR(255) - Hash of the original PDF file
- `extraction_timestamp` TIMESTAMP - When extraction was performed
- `title` VARCHAR(1000) - Extracted paper title
- `abstract_text` TEXT - Extracted abstract content
- `language` VARCHAR(10) - Detected document language
- `page_count` INTEGER - Total number of pages processed
- `extraction_methods` TEXT - JSON array of extraction methods used
- `processing_time` DOUBLE PRECISION - Processing time in seconds
- `errors` TEXT - JSON array of extraction errors
- `warnings` TEXT - JSON array of extraction warnings
- `extraction_coverage` DOUBLE PRECISION - Coverage percentage (0-100%)
- `confidence_scores` TEXT - JSON object with confidence metrics
- `created_at` TIMESTAMP - Record creation time
- `updated_at` TIMESTAMP - Last update time

**Relationships:**
- One-to-one with `Paper`
- One-to-many with all extraction content tables

## Content Tables

### 3. Extracted Sections Table (Document Structure)

**Table:** `extracted_sections`

Represents the hierarchical structure of the document (headings, sections, subsections).

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL - Foreign key to paper_extractions
- `section_id` VARCHAR(100) - ID from extractor service
- `label` VARCHAR(50) - Section label (e.g., "1.1", "A.1")
- `title` VARCHAR(1000) - Section title/heading
- `section_type` VARCHAR(50) - Type: introduction, methods, results, etc.
- `level` INTEGER - Heading level (1=main section, 2=subsection, etc.)
- `page_start` INTEGER - Starting page number
- `page_end` INTEGER - Ending page number
- `order_index` INTEGER - Ordering within document
- `parent_section_id` UUID - Self-referencing for hierarchy

**Relationships:**
- Self-referencing hierarchy (parent/child sections)
- One-to-many with `ExtractedParagraph`

### 4. Extracted Paragraphs Table (Text Content)

**Table:** `extracted_paragraphs`

Stores individual text paragraphs within sections.

**Columns:**
- `id` UUID PRIMARY KEY
- `section_id` UUID NOT NULL - Foreign key to extracted_sections
- `text` TEXT - Paragraph content
- `page` INTEGER - Page number
- `order_index` INTEGER - Order within section
- `bbox_x1`, `bbox_y1`, `bbox_x2`, `bbox_y2` DOUBLE PRECISION - Bounding box coordinates
- `style` TEXT - JSON with font/style information

### 5. Extracted Figures Table (Images & Charts)

**Table:** `extracted_figures`

Stores extracted images, charts, diagrams, and visual content.

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL
- `figure_id` VARCHAR(100) - ID from extractor
- `label` VARCHAR(100) - Figure label (e.g., "Figure 1", "Fig. 2")
- `caption` TEXT - Figure caption
- `page` INTEGER - Page number
- `figure_type` VARCHAR(50) - Type: figure, chart, diagram, etc.
- `bbox_x1`, `bbox_y1`, `bbox_x2`, `bbox_y2` DOUBLE PRECISION - Bounding box
- `bbox_confidence` DOUBLE PRECISION - Detection confidence (0-1)
- `image_path` VARCHAR(500) - Path to extracted image file
- `thumbnail_path` VARCHAR(500) - Path to thumbnail image
- `figure_references` TEXT - JSON array of section IDs referencing this figure
- `ocr_text` TEXT - Text extracted from figure via OCR
- `ocr_confidence` DOUBLE PRECISION - OCR confidence score (0-1)
- `order_index` INTEGER - Order within document

**Data Available:**
- Original figure images
- Thumbnails for quick preview
- OCR-extracted text for searchability
- Bounding box coordinates for precise positioning
- Cross-references to document sections

### 6. Extracted Tables Table (Tabular Data)

**Table:** `extracted_tables`

Stores structured tabular data with multiple export formats.

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL
- `table_id` VARCHAR(100) - ID from extractor
- `label` VARCHAR(100) - Table label (e.g., "Table 1", "Tab. 2")
- `caption` TEXT - Table caption
- `page` INTEGER - Page number
- `bbox_x1`, `bbox_y1`, `bbox_x2`, `bbox_y2` DOUBLE PRECISION - Bounding box
- `bbox_confidence` DOUBLE PRECISION - Detection confidence
- `headers` TEXT - JSON array of header rows
- `rows` TEXT - JSON array of data rows
- `structure` TEXT - Detailed structure as JSON
- `csv_path` VARCHAR(500) - Path to CSV export
- `html` TEXT - HTML representation
- `table_references` TEXT - JSON array of referencing sections
- `order_index` INTEGER - Order within document

**Data Available:**
- Structured data in JSON format (headers, rows)
- CSV exports for data analysis
- HTML representation for display
- Original table structure preservation

### 7. Extracted Equations Table (Mathematical Formulas)

**Table:** `extracted_equations`

Stores mathematical equations in multiple formats.

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL
- `equation_id` VARCHAR(100) - ID from extractor
- `label` VARCHAR(100) - Equation label (e.g., "Equation 1", "Eq. (2)")
- `latex` TEXT - LaTeX representation
- `mathml` TEXT - MathML representation (optional)
- `page` INTEGER - Page number
- `is_inline` BOOLEAN - Inline vs display equation
- `bbox_x1`, `bbox_y1`, `bbox_x2`, `bbox_y2` DOUBLE PRECISION - Bounding box
- `order_index` INTEGER - Order within document

**Data Available:**
- LaTeX format for rendering
- MathML for accessibility
- Distinction between inline and display equations

### 8. Extracted Code Blocks Table (Code Snippets)

**Table:** `extracted_code_blocks`

Stores programming code and algorithms found in papers.

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL
- `code_id` VARCHAR(100) - ID from extractor
- `language` VARCHAR(50) - Programming language
- `code` TEXT - Actual code content
- `page` INTEGER - Page number
- `context` TEXT - Surrounding text for context
- `has_line_numbers` BOOLEAN - Whether code includes line numbers
- `bbox_x1`, `bbox_y1`, `bbox_x2`, `bbox_y2` DOUBLE PRECISION - Bounding box
- `order_index` INTEGER - Order within document

**Data Available:**
- Language-specific code highlighting
- Contextual information around code
- Original formatting preservation

### 9. Extracted References Table (Bibliography)

**Table:** `extracted_references`

Stores bibliographic citations with enrichment from external APIs.

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL
- `reference_id` VARCHAR(100) - ID from extractor
- `raw_text` TEXT - Original citation text
- `title` VARCHAR(1000) - Extracted title
- `authors` TEXT - JSON array of author names
- `year` INTEGER - Publication year
- `venue` VARCHAR(500) - Journal/conference name
- `doi` VARCHAR(200) - Digital Object Identifier
- `url` VARCHAR(1000) - Publication URL
- `arxiv_id` VARCHAR(50) - ArXiv identifier
- `crossref_data` TEXT - JSON data from CrossRef API
- `openalex_data` TEXT - JSON data from OpenAlex API
- `unpaywall_data` TEXT - JSON data from Unpaywall API
- `cited_by_sections` TEXT - JSON array of citing section IDs
- `citation_count` INTEGER - Number of times cited in document
- `order_index` INTEGER - Order within bibliography

**Data Available:**
- Structured bibliographic metadata
- External API enrichment data
- Citation context and frequency
- Persistent identifiers (DOI, ArXiv)

### 10. Extracted Entities Table (Named Entities)

**Table:** `extracted_entities`

Stores named entities like persons, organizations, locations.

**Columns:**
- `id` UUID PRIMARY KEY
- `paper_extraction_id` UUID NOT NULL
- `entity_id` VARCHAR(100) - ID from extractor
- `entity_type` VARCHAR(50) - PERSON, ORGANIZATION, LOCATION, etc.
- `name` VARCHAR(500) - Entity name
- `uri` VARCHAR(1000) - Linked data URI (optional)
- `page` INTEGER - Page number
- `context` TEXT - Surrounding text
- `confidence` DOUBLE PRECISION - Recognition confidence (0-1)
- `order_index` INTEGER - Order within document

## Data Relationships and Usage

### Primary Relationships

1. **Paper → PaperExtraction**: One-to-one relationship
2. **PaperExtraction → Content Tables**: One-to-many relationships
3. **ExtractedSection → ExtractedParagraph**: One-to-many hierarchy
4. **ExtractedSection → ExtractedSection**: Self-referencing hierarchy

### Cross-References

- **Figures**: Referenced by sections via `figure_references` JSON field
- **Tables**: referenced by sections via `table_references` JSON field
- **Citations**: Track which sections cite them via `cited_by_sections`

### Indexing Strategy

Key indexes for performance:
- `papers.extraction_status` - For querying extraction progress
- `paper_extractions.paper_id` - For joining with papers
- `paper_extractions.extraction_id` - For extractor service queries
- Content tables have `paper_extraction_id` and `order_index` indexes

## Data Usage Patterns

### 1. Full Document Reconstruction
Query all content tables by `paper_extraction_id` and use `order_index` to recreate original document structure.

### 2. Content-Specific Queries
- **Figures**: Search by type, caption text, or OCR content
- **Tables**: Query structured data in headers/rows JSON
- **Equations**: Search LaTeX expressions
- **Code**: Filter by programming language
- **References**: Search by author, venue, or year
- **Entities**: Filter by type (PERSON, ORG, etc.)

### 3. Cross-Document Analysis
- Compare extraction coverage across papers
- Analyze reference patterns and citations
- Track processing performance metrics
- Identify common entities across corpus

### 4. Quality Metrics
- `extraction_coverage`: Completeness percentage
- `confidence_scores`: Extraction quality metrics
- `bbox_confidence`: Positional accuracy
- `ocr_confidence`: Text recognition quality

## Storage Considerations

### File Storage
- **Figures**: Original images and thumbnails stored on filesystem
- **Tables**: CSV exports for data analysis
- **File paths**: Stored as relative paths in database

### JSON Fields
Many fields store complex data as JSON:
- `extraction_methods`, `errors`, `warnings` (PaperExtraction)
- `headers`, `rows`, `structure` (Tables)
- `authors`, `crossref_data`, `openalex_data` (References)
- `style` (Paragraphs)

### Performance Notes
- Use pagination for large result sets
- JSON fields are searchable via PostgreSQL JSON operators
- Consider materialized views for complex aggregations
- Archive old extractions to manage storage growth

This schema provides comprehensive storage for all types of content extracted from research papers, enabling rich querying, analysis, and reconstruction capabilities.