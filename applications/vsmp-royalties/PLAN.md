# VSMP Royalties Rails Application - Implementation Plan

## Project Overview

Migrate music publishing royalties management from IndexedDB-based JavaScript app to Rails 8.1 server-rendered application. Use data model from `~/Projects/vsmp-app`, architectural conventions from `~/Projects/vsmp/portal`.

**Tech Stack**: Rails 8.1, PostgreSQL (cluster), Hotwire (Turbo + Stimulus), Minitest, SolidQueue

---

## Phase 1: Foundation & Setup

### 1.1 Dependencies & Configuration

**Gemfile additions:**

- `solid_queue` - Database-backed ActiveJob adapter (Rails 8 default)
- `mission_control-jobs` - Web UI for job monitoring
- `annotate` - Schema documentation in models
- `aws-sdk-s3` - For ActiveStorage S3 compatibility

**Linting setup:**

- Create `.rubocop.yml` in this directory with app-specific rules
- Add `rubocop-rails-omakase` to root `Gemfile` for monorepo-wide linting
- Configure pre-commit hook to run rubocop on this directory
- Add linting command: `bundle exec rubocop applications/vsmp-royalties`

**Configuration:**

- Set ActiveJob adapter to SolidQueue in `application.rb`
- Configure Active Storage for Hetzner S3-compatible storage in `storage.yml`
- Add annotate to `Rakefile` for auto-documentation
- Mount Mission Control at `/jobs` for job monitoring

### 1.2 Database Setup

**Use cluster PostgreSQL instance** (see APPS.md for full instructions):

1. **Add user to init scripts** (`platform/postgresql/init-scripts.yaml`):
   - Add user creation in `02-create-users.sql`
   - Add database grants in `03-grant-permissions.sql`

2. **Add password to secret** (`platform/postgresql/secret-auth.yaml`):

   ```yaml
   stringData:
     vsmp-royalties-password: "${POSTGRES_VSMP_ROYALTIES_PASSWORD}"
   ```

3. **Create database and user on server:**

   ```bash
   kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
     "CREATE DATABASE vsmp_royalties"
   kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
     "CREATE USER vsmp_royalties WITH PASSWORD '<password>'"
   kubectl exec -it postgresql-0 -n platform -- psql -U postgres -c \
     "GRANT ALL PRIVILEGES ON DATABASE vsmp_royalties TO vsmp_royalties"
   ```

4. **Configure Rails database.yml** to construct DATABASE_URL from env vars:

   ```ruby
   # config/database.yml
   production:
     url: <%= "postgresql://#{ENV['DB_USER']}:#{ENV['DB_PASSWORD']}@#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_NAME']}" %>
   ```

**PostgreSQL features:**

- Use `tstzrange` for date ranges where appropriate
- Enable UUID extension if needed for external IDs
- Set up foreign key constraints
- SolidQueue will create its own tables for job management

---

## Phase 2: Core Data Model

### 2.1 Models & Schema (in dependency order)

**Independent entities (lookup tables):**

1. **Writer** - Represents music creators
   - `first_name:string`, `last_name:string`, `ip_code:string` (unique index)
   - Validations: presence of all fields, uniqueness of ip_code
   - Display name: "#{last_name}, #{first_name} [#{ip_code}]"

2. **Territory** - Geographic regions
   - `name:string`, `iso_code:string` (2-char)
   - Index on iso_code

3. **RightType** - Type of royalty rights
   - `name:string`, `group:string` (MECH, PERF, SYNC, PRINT)
   - Used for coefficient calculation in statements

4. **Batch** - Royalty batches from sources
   - `code:string` (unique), `description:text`

5. **Exploitation** - Usage/licensing details
   - `licence_id:string`, `title:string`, `artist:string`, `description:text`, `format:string`

**Core entities:**

1. **Work** - Musical compositions
   - `work_id:string` (indexed), `title:string`
   - `has_many :work_writers`, `has_many :writers, through: :work_writers`
   - `has_many :royalties`

2. **WorkWriter** - Join table for Work ↔ Writer many-to-many
   - `belongs_to :work`, `belongs_to :writer`

3. **Import** - CSV upload tracking
   - `original_file_name:string`, `fiscal_year:integer`, `fiscal_quarter:integer`
   - `number_of_royalties_added:integer`, `created_at:datetime`
   - `has_one_attached :csv_file` (Active Storage)
   - `has_many :royalties, dependent: :destroy_async`
   - Callback: `after_create :start_import_job`

4. **Royalty** - Individual royalty line items
   - References: `batch_id`, `work_id`, `right_type_id`, `territory_id`, `exploitation_id`, `import_id`, `statement_id:integer` (nullable)
   - Identifiers: `agreement_code:string`, `custom_work_id:string`
   - Financial fields (all `decimal(20,18)`):
     - `distributed_amount` - Original amount
     - `final_distributed_amount` - After coefficient adjustment (populated on statement generation)
     - `percentage_paid`, `unit_sum`
     - `wht_adj_received_amount`, `wht_adj_source_amount`
     - `direct_collect_fee_taken`, `direct_collected_amount`
   - Metadata: `credit_or_debit:string`, `recording_artist:string`, `av_production_title:string`
   - Dates: `period_start:date`, `period_end:date`
   - Sources: `source_name:string`, `revenue_source_name:string`, `generated_at_cover_rate:string`
   - Indexes: composite `[import_id, work_id]`, individual on foreign keys
   - `belongs_to :batch, :work, :right_type, :territory, :exploitation, :import`
   - `belongs_to :statement, optional: true`

5. **Statement** - Generated writer statements
    - `fiscal_year:integer`, `fiscal_quarter:integer`
    - `created_at:datetime`, `invoiced:boolean` (default: false), `invoiced_at:datetime`
    - `has_many :statement_writers`, `has_many :writers, through: :statement_writers`
    - `has_many :royalties`
    - `has_many :statement_conflicts, dependent: :destroy`
    - `has_one_attached :export_csv` (Active Storage)
    - Callback: `after_create :populate_royalties_job`
    - Validations: presence of fiscal_year, fiscal_quarter

6. **StatementWriter** - Join table for Statement ↔ Writer
    - `belongs_to :statement`, `belongs_to :writer`

7. **StatementConflict** - Track royalties already on other statements
    - `belongs_to :statement`
    - `royalty_id:bigint`, `conflicting_statement_id:bigint`
    - Status: `resolved:boolean` (default: false)

### 2.2 Implementation Strategy

**Use Rails generators throughout:**

```bash
# For lookup tables (simple CRUD)
rails generate scaffold Writer first_name:string last_name:string ip_code:string:uniq
rails generate scaffold Territory name:string iso_code:string
rails generate scaffold RightType name:string group:string
rails generate scaffold Batch code:string:uniq description:text
rails generate scaffold Exploitation licence_id:string title:string artist:string description:text format:string

# For core entities
rails generate scaffold Work work_id:string:index title:string
rails generate model WorkWriter work:references writer:references
rails generate scaffold Import original_file_name:string fiscal_year:integer fiscal_quarter:integer number_of_royalties_added:integer
rails generate model Royalty batch:references work:references right_type:references territory:references exploitation:references import:references statement:references{optional} agreement_code:string ...
rails generate scaffold Statement fiscal_year:integer fiscal_quarter:integer invoiced:boolean invoiced_at:datetime
rails generate model StatementWriter statement:references writer:references
rails generate model StatementConflict statement:references royalty_id:bigint conflicting_statement_id:bigint resolved:boolean

# For jobs
rails generate job ImportRoyalties
rails generate job PopulateStatement
rails generate job ExportStatement
```

**Migration order:**

1. Independent lookup tables first (writers, territories, right_types, batches, exploitations)
2. Works table
3. Work-Writer join table
4. Imports table + Active Storage tables (`rails active_storage:install`)
5. Royalties table with all foreign keys
6. Statements table + Active Storage tables
7. Statement-Writer join table
8. Statement conflicts table
9. SolidQueue tables (`rails solid_queue:install`)

---

## Phase 3: CSV Import System

### 3.1 Import Flow

**User interaction:**

1. Navigate to `/imports/new`
2. Upload CSV file, select fiscal year/quarter
3. Create Import record → triggers `ImportRoyaltiesJob`
4. Polling UI shows progress (Turbo Streams)
5. Redirect to import show page on completion

### 3.2 ImportRoyaltiesJob

**Job structure:**

```ruby
class ImportRoyaltiesJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    import = Import.find(import_id)
    csv_file = import.csv_file.download

    royalties_added = 0

    CSV.parse(csv_file, headers: true) do |row|
      Royalty.transaction do
        royalty = build_royalty_from_row(row)
        royalty.import = import
        royalty.save!
        royalties_added += 1
      end
    end

    import.update!(number_of_royalties_added: royalties_added)
  end

  private

  def build_royalty_from_row(row)
    # Find or create associated entities
    batch = find_or_create_batch(row)
    work = find_or_create_work(row)
    right_type = find_or_create_right_type(row)
    territory = find_or_create_territory(row)
    exploitation = find_or_create_exploitation(row)

    # Build royalty with all fields mapped from CSV
    Royalty.new(
      batch: batch,
      work: work,
      right_type: right_type,
      territory: territory,
      exploitation: exploitation,
      # ... map all 32 CSV fields
    )
  end

  def find_or_create_batch(row)
    Batch.find_or_create_by!(code: row['BATCH_ID']) do |b|
      b.description = row['BATCH_DESCRIPTION']
    end
  end

  def parse_writers(writers_string)
    # Parse "Lee, Mark Christopher [IP112084]" format
    # Regex: /(.+?),\s*(.+?)\s*\[([^\]]+)\]/
    # Create WorkWriter records
  end

  # Similar for other entities...
end
```

**Field mappings** (CSV → Royalty):

- `AGREEMENT_ID` → `agreement_code`
- `BATCH_ID` → find/create Batch
- `WORK_ID` → `work.work_id`, `WORK_TITLE` → `work.title`
- `WRITERS` → parse and create WorkWriter associations
- `RIGHT_TYPE`, `RIGHT_TYPE_GROUP` → find/create RightType
- `TERRITORY_ID`, `TERRITORY_ISO_ALPHA_2_CODE` → find/create Territory
- `EXPLOITATION_*` fields → find/create Exploitation
- All financial fields → direct mapping to decimals
- Date fields → parse with `Date.parse`

### 3.3 Progress Tracking

Use Turbo Streams + polling:

- Job updates Import record with progress count
- View polls `/imports/:id/progress` endpoint
- Controller streams updates via Turbo Stream

---

## Phase 4: Statement Generation

### 4.1 Statement Creation Flow

**User interaction:**

1. Navigate to `/statements/new`
2. Select writers (checkboxes/multi-select)
3. Select fiscal year and quarter
4. Submit → creates Statement → triggers `PopulateStatementJob`

### 4.2 PopulateStatementJob

**Job responsibilities:**

1. Find all royalties matching:
   - Writers in statement.writers
   - Fiscal period matches import.fiscal_year/quarter
   - Not already assigned to another statement
2. Detect conflicts (royalties on other statements)
3. Apply coefficient to distributed_amount:
   - MECH/PRINT: 0.8
   - SYNC: 0.7
   - PERF (default): 0.6
4. Set `final_distributed_amount` = `distributed_amount * coefficient`
5. Associate royalties with statement
6. Create StatementConflict records if needed
7. Trigger `ExportStatementJob`

**Conflict detection:**

```ruby
def detect_conflicts(royalty, statement)
  if royalty.statement_id.present? && royalty.statement_id != statement.id
    StatementConflict.create!(
      statement: statement,
      royalty_id: royalty.id,
      conflicting_statement_id: royalty.statement_id
    )
  end
end
```

### 4.3 ExportStatementJob

**Job responsibilities:**

1. Load all royalties with eager loading: `.includes(work: :writers, batch, right_type, territory, exploitation)`
2. Generate CSV with 34 columns (all original fields + computed fields)
3. Add footer row with totals
4. Attach to statement via Active Storage

**CSV structure:**

- Headers: All original CSV columns + computed metadata
- Rows: One per royalty with joined data
- Footer: Total `final_distributed_amount`, total `distributed_amount`, margin %

---

## Phase 5: Statement Management

### 5.1 Statement Lifecycle

**States:**

1. **Generated** - Created, conflicts may exist
2. **Ready** - No unresolved conflicts
3. **Invoiced** - Marked as sent, immutable

**Actions:**

- View: Show all royalties, summary totals, conflicts
- Export: Download CSV (already generated by job)
- Resolve conflicts: Accept duplicate entries, mark conflict resolved
- Mark invoiced: Sets `invoiced = true`, `invoiced_at = Time.current`
- Delete: Only if not invoiced

### 5.2 Conflict Resolution

**UI flow:**

1. Statement show page lists unresolved conflicts
2. For each conflict, show:
   - Royalty details (work, amount, period)
   - Original statement ID
   - Resolution options: "Accept duplicate" or "Remove from this statement"
3. Accepting marks `statement_conflicts.resolved = true`
4. Can't mark statement as invoiced until all conflicts resolved

---

## Phase 6: Controllers & Views

### 6.1 Controllers (RESTful, minimal logic)

**ImportsController:**

- `index` - List all imports
- `new` - Upload form
- `create` - Create import, attach file, trigger job
- `show` - View import details, royalties count
- `progress` - Turbo Stream endpoint for polling

**StatementsController:**

- `index` - List statements (with filters by writer, period, invoiced status)
- `new` - Form to select writers and fiscal period
- `create` - Create statement, trigger populate job
- `show` - View statement with royalties, totals, conflicts
- `invoice` - POST action to mark as invoiced
- `destroy` - Delete if not invoiced

**WritersController:**

- `index` - List writers (for selection in statement creation)
- `show` - View writer details, past statements

**WorksController, RoyaltiesController:**

- `index` - Browse/search functionality
- `show` - Detail views

### 6.2 Views (Simple ERB)

**Layout structure:**

- Simple navigation: Imports | Statements | Writers | Works
- Flash messages for success/errors
- Minimal inline CSS or simple classless framework

**Key views:**

- `imports/new.html.erb` - File upload form with fiscal period inputs
- `imports/show.html.erb` - Import details, progress indicator (Turbo Frame)
- `statements/new.html.erb` - Writer selection (checkboxes), period inputs
- `statements/show.html.erb` - Royalties table, summary card, conflicts list, invoice button
- `statements/index.html.erb` - Filterable table with search by writer/period

**Turbo integration:**

- Import progress: Turbo Frame polls for updates
- Statement creation: Turbo Stream shows "Generating..." message
- No full page reloads for status updates

---

## Phase 7: Testing Strategy (Minitest + TDD)

### 7.1 Model Tests

**Test files:**

- `test/models/royalty_test.rb` - Associations, validations
- `test/models/statement_test.rb` - Lifecycle, conflict detection
- `test/models/import_test.rb` - Callback triggers

**Key tests:**

- Royalty associations work correctly
- Statement validates fiscal year/quarter presence
- Work-Writer many-to-many relationship
- Statement conflict uniqueness

### 7.2 Job Tests

**Test files:**

- `test/jobs/import_royalties_job_test.rb`
- `test/jobs/populate_statement_job_test.rb`
- `test/jobs/export_statement_job_test.rb`

**Key tests:**

- Import job parses CSV correctly, creates all entities
- Writer parsing regex handles format variations
- Populate job applies correct coefficients per right type
- Conflict detection works across statements
- Export job generates valid CSV with correct totals

**Fixtures:**

- `test/fixtures/files/sample_master.csv` - 10-20 rows from master.csv
- Fixture data for writers, works, statements

### 7.3 Integration Tests

**System tests (Capybara):**

- Upload CSV → wait for processing → verify royalties created
- Create statement → select writers → verify conflicts shown
- Resolve conflicts → mark as invoiced
- Export statement → download CSV → verify contents

### 7.4 TDD Workflow

For each feature:

1. Write failing model test
2. Implement model, make test pass
3. Write failing job test
4. Implement job, make test pass
5. Write failing integration test
6. Implement controller/view, make test pass

---

## Phase 8: UI/UX Refinements

### 8.1 Key Features from JavaScript App

**Dashboard/Home:**

- Quick stats: Total imports, total statements, pending conflicts
- Recent activity feed

**Import Management:**

- Table showing all imports with status, date, royalties count
- Click to view details

**Statement List:**

- Filter by: Writer, fiscal period, invoiced status
- Sort by: Date created, total amount
- Visual indicators for conflicts

**Statement Detail:**

- Summary card: Total FDA, total distributed, margin %, writer names
- Royalties table: Sortable, paginated (use Turbo Frames)
- Conflict resolution section if applicable
- Export button, invoice button (disabled if conflicts exist)

### 8.2 Stimulus Controllers

Minimal JavaScript for:

- File upload preview (show filename)
- Writer selection (select all/none)
- Polling for import progress
- Sortable tables (optional, use Turbo Frames + params)

---

## Phase 9: Deployment Considerations

### 9.1 Environment Setup

**Environment variables** (see APPS.md for HelmRelease configuration):

```yaml
env:
  - name: DB_USER
    value: vsmp_royalties
  - name: DB_HOST
    value: postgresql
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: vsmp_royalties
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-auth
        key: vsmp-royalties-password
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: hetzner-s3-credentials
        key: access-key-id
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: hetzner-s3-credentials
        key: secret-access-key
  - name: AWS_REGION
    value: eu-central
  - name: AWS_ENDPOINT
    value: https://s3.hetzner.cloud
  - name: S3_BUCKET
    value: vsmp-royalties
```

**Production gems:**

- `solid_queue` configured for production
- Active Storage configured for Hetzner S3
- Redis for Turbo Streams (if using ActionCable)

### 9.2 Database

- PostgreSQL on cluster with sufficient storage for large CSVs
- Indexes on frequently queried columns
- Consider partitioning royalties table if > 1M rows
- SolidQueue uses same database for job persistence

### 9.3 Background Jobs

- Mission Control Jobs UI mounted at `/jobs`
- Configure job retries, error handling in `config/solid_queue.yml`
- Monitor job queue depths via Mission Control
- SolidQueue worker process runs in same container as web server

---

## Implementation Order

**Phase 1: Foundation**

1. Set up gems, configure SolidQueue and ActiveStorage
2. Configure database connection to cluster PostgreSQL
3. Set up linting with rubocop
4. Configure Hetzner S3 for ActiveStorage

**Phase 2: Data Model**

1. Use generators to create all models and migrations
2. Run migrations in correct order (lookup tables → royalties → statements)
3. Add associations, validations, and custom methods to models
4. Write model tests (TDD)

**Phase 3: Import System**

1. Use generator to create ImportRoyaltiesJob
2. Implement CSV parsing with find_or_create logic
3. Write job tests with fixture CSV
4. Build Imports controller/views (modify scaffolded code)
5. Add progress tracking with Turbo

**Phase 4: Statement Generation**

1. Use generator to create PopulateStatementJob and ExportStatementJob
2. Implement coefficient logic and conflict detection
3. Implement CSV export with totals
4. Write job tests

**Phase 5: Statement Management**

1. Build Statements controller/views (modify scaffolded code)
2. Implement conflict resolution UI
3. Add invoice action
4. Write integration tests

**Phase 6: Polish & Testing**

1. Add filtering/search to index pages
2. Improve UI with better tables, summary cards
3. Complete test coverage
4. Add dashboard/home page
5. Configure deployment (HelmRelease, ImagePolicy, GitHub Actions)

---

## Success Criteria

- [ ] All CSV fields captured in database
- [ ] Import job processes large files (>10k rows) without timeout
- [ ] Statement generation applies correct coefficients
- [ ] Conflict detection prevents duplicate royalty assignments
- [ ] Export CSV matches original format with computed fields
- [ ] Invoice status prevents modifications
- [ ] Test coverage >80%
- [ ] UI matches JavaScript app functionality
- [ ] No IndexedDB - all data server-side
- [ ] Mission Control Jobs UI accessible at `/jobs` for monitoring
- [ ] ActiveStorage configured for Hetzner S3
- [ ] Database connected to cluster PostgreSQL instance
- [ ] Linting configured and passing in pre-commit hooks

---

## Notes

- **No authentication needed** (per original spec)
- **Vanilla Rails** - No React, no complex frontend framework
- **POROs via Jobs** - Jobs encapsulate domain logic, not separate service classes
- **TDD throughout** - Write tests first, especially for CSV parsing
- **Small commits** - Commit after each green test suite
- **Use generators** - Always use `rails generate` for models, migrations, scaffolds, jobs

---

## Future Features

### Process-Oriented UX Flow

Currently the app is planned as a simple CRUD interface over the data model. A future enhancement would be to create a guided workflow that takes users through the statement generation process step-by-step:

1. **Import Phase**: Upload CSV → Monitor progress → Review imported data
2. **Statement Creation Phase**: Select fiscal period → Review available writers → Select writers → Generate statement
3. **Review Phase**: Review statement details → Resolve any conflicts → Verify totals
4. **Finalization Phase**: Export CSV → Mark as invoiced → Archive

This would replace the generic navigation with a wizard-like interface that guides users to the next logical step based on system state (e.g., "You have unprocessed imports" or "Statement ready for review").

**Implementation considerations:**

- Add `state` field to Statement model (draft, reviewing, ready, invoiced)
- Create dashboard with actionable cards for each phase
- Use Turbo Frames for in-place state transitions
- Add progress indicators showing completion status

### Reconciliation System

Track what was actually paid out vs what the system calculated, with reconciliation dashboard:

**Data Model Extensions:**

- Add `Payout` model:
  - `statement_id`, `payout_date`, `amount_paid`, `payment_method`, `reference_number`
  - `reconciled:boolean`, `variance:decimal`
- Add `PayoutRoyalty` join table to track individual royalty payouts
- Add `actual_paid_amount:decimal` to Royalty model

**Reconciliation Features:**

- Import bank transaction data and match to statements
- Manual payout entry for historical corrections
- Variance tracking: `calculated_amount` vs `actual_paid_amount`
- Reconciliation dashboard showing:
  - Total outstanding (statements not paid)
  - Total variance (over/under payments)
  - Unreconciled statements
  - Historical payment trends
- Adjustment system: Create correction entries for past mistakes
- Audit trail: Track all payout changes with timestamps and reasons

**UI Components:**

- Reconciliation view comparing statement totals to actual payouts
- Variance report grouped by writer, period, or work
- Correction workflow for fixing historical errors
- Payment history timeline per writer
- Export reconciliation reports for accounting

This would enable proper financial tracking and ensure all payments are accounted for, with clear visibility into any discrepancies between calculated and actual amounts.
