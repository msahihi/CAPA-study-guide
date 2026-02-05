# Changelog

All notable changes to the CAPA Cheatsheet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-05

### Added

- Initial semantic versioning for CAPA Cheatsheet
- Version header with validated tool versions:
  - Argo CD v3.3.0
  - Argo Workflows v3.7.9
  - Argo Rollouts v1.8.3
  - Argo Events v1.9.10
- CHANGELOG.md to track version history

### Validated

- **Cheatsheet**: All CRD examples validated (Argo CD, Workflows, Rollouts, Events)
- **Labs**: 20 lab exercises validated (66+ YAML manifests, 100% pass rate)
  - Argo CD: 6 labs (15+ manifests)
  - Argo Workflows: 5 labs (12 workflows)
  - Argo Rollouts: 5 labs (14 rollouts)
  - Argo Events: 4 labs (25 manifests)
- **Domains**: 24 domain documentation files validated (67+ examples, 99%+ accuracy)
  - Argo CD: 7 domain docs
  - Argo Workflows: 6 domain docs
  - Argo Rollouts: 6 domain docs
  - Argo Events: 5 domain docs
- **Mock Questions**: 120 exam questions validated (96.7% accuracy)
- Markdown linting (markdownlint-cli2): PASSED (0 errors)
- Link validation (lychee): PASSED (310 links checked, 0 broken)
- CRD field structure verified using `kubectl explain`

### Changed

- Updated Argo CD Lab 01 version outputs to v3.3.0/v3.2.6
- Updated Argo Workflows Lab 01 version references from v3.5.4 to v3.7.9

### Deprecated

- N/A (Initial versioned release)

### Removed

- N/A (Initial versioned release)

### Fixed

- Fixed 25 broken links in documentation
- Corrected typo in workflows variables-artifacts.md ({{pod.namespace}})
- Fixed field name in mock-exam-set-2.md (spec.namespaceResourceWhitelist)

### Security

- N/A (Initial versioned release)

---

## Version Increment Rules

### MAJOR version (X.0.0)

Increment when:

- CAPA exam curriculum undergoes significant restructuring
- Exam domain weights change significantly (>10% shift)
- Examples become incompatible with new Argo tool major versions
- Cheatsheet structure fundamentally reorganized

### MINOR version (1.X.0)

Increment when:

- New Argo tool versions add features requiring new sections
- Additional examples added for existing topics
- New best practices or patterns documented
- Exam domain coverage expanded

### PATCH version (1.0.X)

Increment when:

- Bug fixes for incorrect examples or typos
- Link updates or corrections
- Formatting improvements
- Minor clarifications to existing content

---

## How to Read This Changelog

- **Added**: New features, sections, or examples
- **Changed**: Updates to existing content (not backward compatible)
- **Deprecated**: Features marked for removal (still present, discouraged)
- **Removed**: Features or sections removed
- **Fixed**: Bug fixes for incorrect information
- **Security**: Security-related updates or notices
- **Validated**: Confirmation that content works with specified tool versions
