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

### Changed
- **Breaking change:** The way records are retrieved from a given cursor has been changed to no longer use `CONCAT` but instead simply use a compound `WHERE` clause in case of a custom order and having both the custom field as well as the `id` field in the `ORDER BY` query. This is a breaking change since it now changes the internal order of how records with the same value of the `order_by` field are returned.
- Remove `ORDER BY` clause from `COUNT` queries
         
### Fixed
- Only trigger one SQL query to load the records from the database and use it to determine if there was a previous / is a next page

### Added
- Description about `order_by` on arbitrary SQL to README.md

## [0.1.3] - 2021-03-17

### Changed
- Make the gem publicly available via github.com/xing/rails_cursor_pagination and release it to Rubygems.org
- Reference changelog file in the gemspec instead of the general releases Github tab

### Removed
- Remove bulk from release: The previous gem releases contained files like the content of the `bin` folder or the Gemfile used for testing. Since this is not useful for gem users, adjust the gemspec file accordingly.

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
