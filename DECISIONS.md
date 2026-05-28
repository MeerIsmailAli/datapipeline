# Decisions

## 1. Ingestion Mechanism Per Source

### SAP → Flat file CSV upload (not API, not IDoc)
**Why:** Real-world SAP-to-external-system integrations typically use flat file exports (via WE21 file ports or ABAP programs writing CSV). IDocs are the canonical SAP interchange format but require an EDI layer to decode — out of scope for a 4-day prototype. OData/BAPI would require live SAP credentials. CSV files delivered via email or shared drive is the most common pattern we'd see from a client's IT team.

**What we handle:** Material documents for fuel and procurement (10 columns). German column headers are not handled in this prototype (we assume English export config). Multiple date formats are handled (YYYYMMDD, DD.MM.YYYY, YYYY-MM-DD, MM/DD/YYYY).

**What we ignore:** IDoc hierarchical segments, BAPI response structures, OData pagination, unit conversion for all SAP UoM codes.

### Utility → CSV export (Green Button-style)
**Why:** The Green Button Download My Data standard (NAESB REQ.21) is widely adopted by US utilities. It produces CSV files with meter ID, dates, usage, unit, cost. PDF bills were considered but are significantly harder to parse reliably (OCR, layout variations). API access varies wildly per utility.

**What we handle:** 10-column CSV with meter/account IDs, date ranges, usage in kWh, cost, tariff name, read type (actual/estimated).

**What we ignore:** PDF parsing, time-of-use interval data, multi-register meters (import/export), XML formats, utility-specific tariff codes.

### Corporate Travel → JSON upload (Concur API structure)
**Why:** Concur is the dominant corporate travel platform. Its Itinerary API v4 returns JSON with typed segments (Air, Car, Hotel, Rail). We match this shape. Navan/TripActions have similar structures. An API pull would require OAuth, so we accept JSON upload for the prototype.

**What we handle:** Flight (with airport code → distance estimation), Hotel (location, nights), Car rental (days, estimated km). Rail is parsed but treated as a generic travel activity.

**What we ignore:** Real OAuth token refresh, Concur webhook callbacks, dining/parking segments, loyalty program data, detailed tax breakdowns.

## 2. Emission Factor Management

**Decision:** Store factors in a database table with temporal validity, fall back to hardcoded defaults.

**Why:** In production, emission factors change annually (EPA eGRID, UK DEFRA). The temporal model lets us recalculate historical data when factors change. The hardcoded fallback ensures the prototype works without pre-seeding data.

## 3. Authentication

**Decision:** Django session-based auth with REST Framework's login endpoint.

**Why:** Simplest setup for a prototype. The login page sets a session cookie; all API calls include CSRF token. Token-based auth (JWT) would be better for mobile/API clients but adds complexity without benefit for this scope.

## 4. Multi-tenancy

**Decision:** Row-level filtering via `organization` foreign key on every model. No schema-per-tenant.

**Why:** Shared-schema with row-level isolation is appropriate for < 100 orgs. It keeps migrations simple and allows cross-org queries (e.g., an admin dashboard). Schema-per-tenant would be necessary at hyperscale but adds deployment complexity.

## 5. Frontend Approach

**Decision:** React with MUI component library, Vite build tool, served as Django static files.

**Why:** MUI gives us a professional-looking UI quickly without custom CSS. Vite is fast for development. Serving as Django static files means a single deployment unit (no separate frontend hosting).

## Questions for the PM

1. **What SAP module is the client using?** (MM, FI, or a custom Z-program?) The export format changes significantly. We assumed MM material documents; if it's FI-AA (assets) the columns are完全不同.

2. **Is there an existing emission factor framework the client prefers?** (EPA, DEFRA, IPCC, or a specific consultant's database?) We used EPA 2025 and UK DEFRA 2025 defaults, but the client may have a pre-existing set.

3. **What's the expected data volume?** (100 rows/month or 10M?) That changes whether we need async ingestion workers, database indexing strategy, and whether SQLite suffices for the prototype.

4. **Who are the auditors and what level of access do they need?** We currently have a LOCKED status — does the auditor get read-only access, or do they need to sign off within the system?

5. **Should we handle data deletion/amendment?** Right now the model is append-only. If a client corrects a data submission, do we need to retract the old record or version it?
