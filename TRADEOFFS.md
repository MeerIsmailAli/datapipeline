# Tradeoffs

## 1. No Async Ingestion Workers

**Not built:** Celery/RQ task queue for asynchronous ingestion processing.

**Why not:** The prototype handles small data volumes (dozens to hundreds of rows per upload). Processing is synchronous within the HTTP request. In production with large SAP exports (100k+ rows) or multiple concurrent uploads, this would block the web process and require background workers. Async ingestion also enables progress reporting and retry logic. For 4 days and the expected dataset size, synchronous is simpler and the tradeoff is acceptable.

## 2. No Emission Factor Versioning / Recalculation Engine

**Not built:** A "recalculate all" button that re-applies current emission factors to historical records.

**Why not:** The EmissionFactor model has valid_from/valid_to dates, so the infrastructure for temporal factors exists. However, EmissionRecord stores the factor value at time of calculation (emission_factor_value), meaning historical records are frozen with the factors that were current when ingested. A recalculation engine would need to know which records to target, re-apply current factors, and create an audit trail of the change. This is essential for annual reporting cycles but out of scope for a prototype where ingestion and review are the primary workflows.

## 3. No PDF / Document Parsing for Utility Bills

**Not built:** OCR-based PDF bill extraction for utility data.

**Why not:** Many facilities teams get PDF bills from their utility — not CSV exports. PDF parsing is a significant engineering effort: every utility uses a different layout, fields shift positions, OCR quality varies, and multilingual bills add complexity. We chose CSV (Green Button format) as the ingestion mechanism because it's a real standard, parseable without machine learning. In production, a tool like DocTR or Amazon Textract would be needed for PDF bills, and that's a separate workstream.
