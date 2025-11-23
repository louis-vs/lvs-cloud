# VSMP Royalties Implementation TODO

## Phase 1: Foundation & Setup

### 1.1 Dependencies & Configuration

- [x] Add gems (solid_queue, mission_control-jobs, annotate, aws-sdk-s3)
- [x] Configure SolidQueue as ActiveJob adapter
- [x] Configure ActiveStorage for S3
- [x] Mount Mission Control at /jobs
- [x] Set up rubocop linting

### 1.2 Deployment Setup

- [x] Create Helm chart structure
- [x] Create HelmRelease and ImagePolicy
- [x] Add CI configuration (.ci/test.sh)
- [x] Update monorepo workflow to run tests
- [x] Configure database.yml to use Rails credentials
- [x] Create secret.yaml template (needs encryption with SOPS)
- [x] Set up PostgreSQL database on cluster
- [x] Configure Rails credentials with DB and S3 secrets
- [x] Encrypt secret.yaml with SOPS
- [x] Deploy initial "hello world" version

### 1.3 Database Setup

- [x] Create PostgreSQL database and user on cluster
- [x] Add credentials to Rails encrypted credentials
- [x] Test database connection

## Phase 2: Core Data Model

- [x] Generate independent models (Writer, Territory, RightType, Batch, Exploitation)
- [x] Generate Work and WorkWriter models
- [x] Generate Import model with ActiveStorage
- [x] Generate Royalty model with all fields
- [x] Generate Statement and related models
- [x] Run migrations
- [x] Add associations and validations
- [x] Write model tests

## Phase 3: CSV Import System

- [x] Generate ImportRoyaltiesJob
- [x] Implement CSV parsing logic
- [x] Implement find_or_create for entities
- [x] Write job tests
- [ ] Build Imports controller/views
- [ ] Add progress tracking with Turbo

## Phase 4: Statement Generation

- [ ] Generate PopulateStatementJob
- [ ] Generate ExportStatementJob
- [ ] Implement coefficient logic
- [ ] Implement conflict detection
- [ ] Implement CSV export
- [ ] Write job tests

## Phase 5: Statement Management

- [ ] Build Statements controller/views
- [ ] Implement conflict resolution UI
- [ ] Add invoice action
- [ ] Write integration tests

## Phase 6: Polish & Testing

- [ ] Add filtering/search to index pages
- [ ] Improve UI with tables and cards
- [ ] Complete test coverage (>80%)
- [ ] Add dashboard/home page

## Deployment Milestones

- [x] Initial deployment (Phase 1)
- [x] Data model deployed (Phase 2)
- [ ] Import system deployed (Phase 3)
- [ ] Statement generation deployed (Phase 4)
- [ ] Full system deployed (Phase 5)
- [ ] Production ready (Phase 6)
