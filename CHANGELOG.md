# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-04-27

### Added

- `HttpCookie.TeslaMiddleware` for easy integration with Tesla

## [0.8.1] - 2025-04-20

### Changed

- added support for Elixir 1.14 (thanks @adamwight!)
- bumped `public_sufx` to 0.6.0, now it no longer downloads the rules list on compilation

## [0.8.0] - 2025-04-10

### Changed

- switched out the optional dep on `axelson/publicsuffix-elixir` for [public_sufx](https://hex.pm/packages/public_sufx), a fork that's published on hex.pm
- removed the `:reject_public_suffixes` option, public suffixes are no always rejected to guard against 'supercookies'

## [0.7.0] - 2025-02-17

### Added
- `:max_cookies` and `:max_cookies_per_domain` options for `HttpCookie.Jar`
- `HttpCookie.ReqPlugin` for easy integration with Req

### Fixed
- Updating last access time

## [0.6.0] - 2024-01-23

### Added
- `HttpCookie.Jar` with basic functionality for a cookie jar
- Comprehensive IETF test suite

## [0.5.1] - 2024-01-20

### Added
- More typespecs

### Changed
- `nimble_parsec` is now a dev-only dependency

## [0.5.0] - 2024-01-16

### Added
- Initial release with core functionality: parsing Set-Cookie headers, URL matching logic
