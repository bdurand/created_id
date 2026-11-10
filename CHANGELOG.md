# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.2.0

### Added

- Added `CreatedId.register_models` to register models that use CreatedId by class name. This allows applications that lazy load classes (i.e. Rails in development mode) to declare their CreatedId models in an initializer without loading them.
- Added `CreatedId.models` to return all models that use CreatedId. This includes loaded models that include the `CreatedId` module and all registered models. Only the base class is returned for single table inheritance models.
- Added `CreatedId::IndexJob` ActiveJob to index an hour on all CreatedId models. If the job is retried after a failure, models that already have an id range stored for the hour are skipped. The job will not index the current hour or a future hour.
- Added `CreatedId::PeriodicJob` ActiveJob that takes no arguments and can be run hourly from a periodic job scheduler to index the previous hour.

## 1.1.2

### Fixed

- Fixed data corruption when re-running `index_ids_for` on an hour that had already been indexed. The range calculation was using the hour's own stored range as a bound, which excluded the hour's true minimum id (and could exclude the maximum) and caused records to be silently dropped from `created_between`, `created_after`, and `created_before` query results. Recalculating an indexed hour is now safe.
- The upper bound used when calculating an hour's id range now always skips the immediately following hour, since adjacent hours' id ranges can legitimately overlap when ids are slightly out of order near an hour boundary.
- Fixed a race condition in `index_ids_for` where two processes indexing the same class and hour concurrently could raise `ActiveRecord::RecordNotUnique`. The save is now retried so the losing process updates the existing row.
- Fixed misspelled `ArgumentError` constant that caused a `NameError` when including `CreatedId` in a non-ActiveRecord class.

### Added

- Creating a record with an explicitly backdated `created_at` in an hour whose id range has already been indexed now raises `CreatedId::CreatedAtChangedError` and rolls back the insert, since the record's id would fall outside the stored range and be invisible to range queries.

## 1.1.1

### Fixed

- Fixed issue with finding id ranges that prevented the query from using the indexed ids.

## 1.1.0

### Changed

- Omit id clause in queries if ids have not been indexed.
- Update queries to use ranges to better support prepared statements.

### Removed

- Drop support for ActiveRecord 5.
- Drop support for Ruby 2.5 and 2.6.

## 1.0.1

### Changed

- Standardize lazy loading of models.

## 1.0.0

### Added

- Initial release.