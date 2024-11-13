# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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