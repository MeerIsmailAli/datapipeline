# Data Model

## Overview

The data model is designed around three core concepts: **multi-tenant organization isolation**, **source-of-truth tracking** (every normalized emission record derives from a raw source record), and **audit trail** (every state transition is logged).

## Entity-Relationship

```
Organization
  ├── OrganizationMembership (user ↔ org with role)
  ├── DataSource (SAP | UTILITY | TRAVEL)
  │     └── IngestionBatch (one upload = one batch)
  │           └── SourceRecord (one raw row/segment)
  │                 └── EmissionRecord (normalized + calculated)
  ├── EmissionFactor (lookup table)
  └── AuditLog (all mutations)
```

## Key Models

### Organization / OrganizationMembership
Multi-tenancy is implemented via a foreign key on every data-bearing model. Users can belong to multiple orgs with roles (ANALYST, ADMIN, AUDITOR). All API queries filter by the user's currently selected org.

### DataSource
Represents a configured source of data (e.g., "SAP Production System", "NationalGrid Utility Portal"). The `config` JSONField stores source-specific settings (API endpoints, file format preferences). `source_type` categorizes into SAP, UTILITY, or TRAVEL — this drives which ingestion handler processes the data.

### IngestionBatch
Each upload/create call creates a batch. Tracks processing status (PENDING → PROCESSING → COMPLETED/FAILED), row/error counts, and timing. This gives analysts a clear audit trail of what data arrived when.

### SourceRecord
The raw, unmodified data exactly as ingested. `raw_data` is a JSONField preserving the original structure. `raw_checksum` is a SHA-256 of the raw data for deduplication. The `category` field (FUEL, PROCUREMENT, ELECTRICITY, FLIGHT, HOTEL, CAR, RAIL) is assigned during parsing based on material type or segment type.

### EmissionRecord
The normalized, calculated emission record. This is the central model:

- **emission_date**: When the emission occurred (from source data, not ingestion date)
- **category**: Same classification as SourceRecord, preserved for traceability
- **scope**: 1 (direct fuel combustion), 2 (purchased electricity), 3 (business travel, purchased goods)
- **source_type**: Which source system produced this (SAP/UTILITY/TRAVEL)
- **activity_type**: Granular activity classifier (e.g., `diesel_fuel`, `flight_long_haul`, `purchased_electricity`)
- **activity_quantity / activity_unit**: Normalized to standard units (L, kg, kWh, km, nights, days)
- **emission_factor / emission_factor_value**: The factor used (or null if using built-in default)
- **calculated_emission_kg_co2e**: quantity × factor_value
- **status**: PENDING_REVIEW → APPROVED/FLAGGED/REJECTED → LOCKED (locked is terminal for audit)

### EmissionFactor
Lookup table for emission factors, keyed by `activity_type`. Supports temporal validity via `valid_from`/`valid_to`, allowing factor updates over time without losing historical calculations. Falls back to built-in constants in `DEFAULT_FACTORS` when no factor exists.

### AuditLog
Immutable log of all CREATE, UPDATE, DELETE, REVIEW, LOCK, INGEST actions. Stores the acting user, target model/object ID, JSON diff of changes, and a human-readable description.

## Scope Categorization

| Source | Category | Scope | Rationale |
|--------|----------|-------|-----------|
| SAP Fuel | FUEL | 1 | Direct combustion of owned/controlled fuels |
| SAP Procurement | PROCUREMENT | 3 | Upstream purchased goods |
| Utility | ELECTRICITY | 2 | Purchased electricity |
| Travel Flight | FLIGHT | 3 | Business travel |
| Travel Hotel | HOTEL | 3 | Business travel accommodation |
| Travel Car | CAR | 3 | Business travel ground transport |

## Unit Normalization

All activity quantities are normalized to standard base units before emission calculation:

- Fuel volumes → Liters (L) or kilograms (kg) via conversion table (GAL→L, LB→kg, T→kg)
- Electricity → Kilowatt-hours (kWh)
- Flight distance → Kilometers (km); estimated from airport coordinates if not provided
- Hotel stays → Nights
- Car rental → Kilometers (estimated 50 km/day default)

## Source-of-Truth Chain

```
Raw Input (CSV/JSON)
  → IngestionBatch (when, who, status)
    → SourceRecord (what was received, unmodified)
      → EmissionRecord (normalized + calculated)
        → AuditLog (every state change)
```

This chain means we can always reconstruct: what data arrived, what we calculated from it, who reviewed it, and what changed.
