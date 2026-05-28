# Sources

## 1. SAP — Fuel & Procurement Data

### Researched Format: Flat file export via SAP WE21 file port (IDoc-like structure)

**What we learned:**
- SAP exports typically come from the MM (Materials Management) module via IDocs (intermediate documents)
- An IDoc has three parts: control record (header metadata), data records (segments with business data), and status records (processing log)
- Common message types: ORDERS (purchase orders), INVOIC (invoices), DESADV (dispatch advice)
- For fuel/procurement data, the relevant segments are E1EDK01 (header), E1EDP01 (item data), E1EDKA1 (partner)
- In practice, non-SAP systems receive flat files (CSV or fixed-width) exported from SAP via WE21 ports or custom ABAP programs
- German column headers are common (e.g., "Werk" for plant, "Belegdatum" for document date) in European deployments
- Unit codes are SAP-specific (e.g., "L" for liters, "KG" for kilograms, "TO" for metric tons) — not always matching ISO standards
- Plant codes are internal SAP identifiers that require a lookup table to map to human-readable locations
- Date formats vary by locale: YYYYMMDD (German), DD.MM.YYYY (European), MM/DD/YYYY (US)

**Our sample data:**
12 rows covering diesel, gasoline, natural gas, LPG, biodiesel (Scope 1) and steel, cement, chemicals (Scope 3).
Each row has realistic plant codes (PLANT01-03), cost centers, document types (WE = goods receipt, GR = goods issue),
and amounts in USD. We used CSV format with standard SAP-like column headers.

**What would break in production:**
- Material master data: our material classification (DIESEL → fuel) is keyword-based and would fail with SAP material numbers like "MAT-10001" instead of descriptive names
- Unit codes: we handle 6 units; SAP has hundreds (e.g., "TNE" for metric tons, "MWH" for megawatt-hours)
- Plant lookup: we store raw plant codes; a real deployment needs a plant→location mapping table
- Language: German headers would crash the CSV parser (column name mismatch)
- File size: SAP exports can be gigabytes; we load everything into memory

---

## 2. Utility — Electricity Data

### Researched Format: Green Button CSV export (NAESB REQ.21 / ESPI standard)

**What we learned:**
- The Green Button standard was developed by the Obama administration and is adopted by major US utilities (PG&E, NationalGrid, SCE, etc.)
- Two data access models: "Download My Data" (CSV/XML via web portal) and "Connect My Data" (API with OAuth)
- Typical CSV columns: Meter ID, Start Date, End Date, Usage (kWh), Cost, Unit, Tariff, Read Type (Actual/Estimated)
- Advanced meters provide interval data (15-min or hourly) with multiple registers (import/export for solar)
- Reading types include: ACTUAL (meter read), ESTIMATED (calculated based on historical usage), and SUBSTITUTE (replacement for a bad read)
- Billing periods rarely align with calendar months — they follow meter-read cycles (e.g., Jan 15–Feb 12)
- Time-of-use tariffs have different rates for on-peak, mid-peak, and off-peak periods
- Some utilities provide demand data (kW peak demand) alongside energy consumption (kWh)

**Our sample data:**
8 rows from two utilities (NationalGrid, EdisonElectric) with realistic account numbers, meter IDs,
monthly billing periods, kWh usage ranging from 3,200 to 125,000, and varying tariff structures.
One row uses ESTIMATED read type (flagged for analyst attention).

**What would break in production:**
- 15-min interval data: our parser assumes monthly billing rows; 15-min data would blow up row counts (2880 rows per meter-month)
- Multi-register meters: solar customers have import/export columns that don't fit our flat structure
- Tariff code complexity: "General-Service-Large" is a simplification; real tariffs have riders and adjustment clauses
- Account hierarchy: utilities bill at account level but emissions reporting needs facility-level allocation
- Green Button XML format: we only handle CSV

---

## 3. Corporate Travel — Flights, Hotels, Ground Transport

### Researched Format: SAP Concur Itinerary API v4 (JSON)

**What we learned:**
- Concur dominates corporate travel management with >50% market share, followed by Navan/TripActions, Egencia, and TravelPerk
- The Itinerary API v4 returns trips containing typed segments: Air, Car, Hotel, Dining, Ride, Rail, Parking, Travel
- Air segments include: vendor, flight number, class of service, start/end airport codes, departure/arrival times, fare
- Hotel segments include: vendor, property name, check-in/out dates, nightly rate, total, cancellation policy
- Car segments include: vendor, pickup/dropoff location and times, daily rate, car class, total
- Distance is not always provided for flights — you often get only airport codes and need to calculate great-circle distance
- Emissions calculation typically uses: distance-based factors for flights (short/medium/long haul), per-night for hotels, per-km for cars
- Concur's API requires OAuth 2.0 with client credentials grant for server-to-server access
- Navan provides a similar GraphQL API with segment-level carbon estimates

**Our sample data:**
8 segments across 3 trips: JFK→LHR round trip with hotel stay, SFO→NRT business trip with hotel,
SEA car rental, and a UK rail journey. Includes realistic vendors (American Airlines, Hilton, Alamo, ANA),
costs, and booking details.

**What would break in production:**
- OAuth token management: our prototype accepts JSON pasted by a user; real API integration needs token refresh, retry, rate limiting
- Missing distances: our airport coordinate table covers ~30 major airports; unlisted airports fall back to 500 km default
- Multi-city itineraries: complex trips with open-jaw routing aren't handled specially
- Currency conversion: we store amounts but don't normalize to a single currency for cost reporting
- Rail emissions: we calculate rail at 0.035 kgCO2e/km but real factors vary by train type (diesel vs electric, high-speed vs regional)
