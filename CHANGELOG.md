# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] - 2026-11-08

### Security

- `HttpCookie.ReqPlugin` no longer forwards the jar's `cookie` header to redirect targets or retries that the cookies don't match
- reject `Secure` cookies set from insecure origins, and don't let insecure origins overwrite existing `Secure` cookies (enforced by `HttpCookie.Jar.put_cookies_from_headers/3`, see the `HttpCookie.Jar.put_cookies/2` docs)
- enforce the `__Secure-` and `__Host-` cookie name prefixes
- domain cookies no longer replace host-only cookies with the same name and path, both are kept and sent like browsers do
- reject `Set-Cookie` headers containing control characters
- invalid request hosts no longer crash the caller or `HttpCookie.Jar.Server`
- remove domain entries left without cookies, so expired cookies can't grow the jar without bound
- require `public_sufx` 0.8, which recognizes public suffixes with a trailing dot and matches in linear time

### Changed

- dropped support for OTP 25, OTP 26 is now the minimum (required by `public_sufx` 0.8)
- host-only cookies are stored under the canonicalized request host, so cookies from hosts like `EXAMPLE.com` or `bücher.de` are now sent back
- the jar's internal storage key now includes the host-only flag, so jars persisted with an older version (e.g. with `:erlang.term_to_binary/1`) must be rebuilt, using them raises
- faster cookie handling: `HttpCookie.from_cookie_string/3` uses 34-61% fewer reductions and `HttpCookie.Jar.get_cookie_header_value/2` 72-91% fewer, since only non-ASCII hosts go through IDNA and the request host is canonicalized once per lookup instead of once per cookie

### Fixed

- cookies are now stored and sent for IPv6 literal hosts and hosts with underscores (e.g. Docker Compose service names), which used to raise

## [0.11.0] - 2026-07-28

### Changed

- support `req` 0.7.x after changes that landed in https://github.com/wojtekmach/req/pull/550 changed internals

## [0.10.1] - 2026-07-01

### Changed

- relaxed `req` dep to allow 0.5.x and 0.6.x

## [0.10.0] - 2026-05-10

### Changed

- dropped support for Elixir 1.14
- bumped `public_sufx` to 0.7.0

## [0.9.1] - 2026-01-28

### Fixed

- Warnings emitted by Elixir 1.20.0-rc.1 (thanks @GRoguelon!)

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
- removed the `:reject_public_suffixes` option, public suffixes are now always rejected to guard against 'supercookies'

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
