# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

These are the latest changes on the project's `master` branch that have not yet been released.

<!---
  If you submit a pull request for this gem, please add a summary of your changes here.
  This will ensure that they're also mentioned in the next release description.
  Follow the same format as previous releases by categorizing your feature into "Added", "Changed", "Deprecated", "Removed", "Fixed", or "Security".
--->

## [0.1.2] - 2021-02-04

### Fixed
- Pagination for relations in which a custom `SELECT` does not contain cursor-relevant fields like `:id` or the field specified via `order_by`

## [0.1.1] - 2021-01-21 

### Added
- Add support for handling `nil` for `order` and `order_by` values as if they were not passed

### Fixed
- Pagination for relations that use a custom `SELECT`

## [0.1.0-pre] - 2021-01-12

### Add
- First version of the gem, including pagination, custom ordering by column and sort-order.
