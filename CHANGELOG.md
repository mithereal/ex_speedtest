# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com),
and this project adheres to [Semantic Versioning](https://semver.org).

## - 2026-11-25

### Added
- **HTTP latency probing (`:http` method):** `Speedtest.Ping.ping/2` now supports Ookla's `/speedtest/latency.txt` HTTP probe as the default method, enabling latency checks in containerized and cloud environments (such as Docker and Render) without raw ICMP socket permissions.
- **Configurable ping options:** `Speedtest.Ping.ping/2`, `Speedtest.choose_best_server/2`, and `Speedtest.run/1` accept `:method` (`:http` or `:icmp`), `:count`, and `:timeout` options.
- **Pluggable HTTP client (`Speedtest.HTTP`):** Added a `Speedtest.HTTP` behaviour with a default `Speedtest.HTTP.HTTPoison` adapter, allowing offline mocking in tests via `Mox`.
- **Automatic `ignoreids` filtering:** `Speedtest.run/1` now merges server IDs from `<server-config ignoreids="...">` into the excluded servers list automatically.
- **Fallback server endpoints:** `Speedtest.fetch_servers/1` now iterates through all fallback Speedtest server list URLs if the primary URL fails.
- **ExUnit test suite:** Added unit and mocked integration tests covering `Speedtest`, `Speedtest.Decoder`, `Speedtest.Ping`, and `Speedtest.Result`.

### Changed
- **Migrated Speedtest API integration from XML to JSON:** Replaced the retired `.php` XML endpoints (`speedtest-config.php` and `speedtest-servers-static.php`, which now redirect to HTML) with Speedtest's JSON endpoints (`/api/js/config-sdk` and `/api/js/servers`).
- **`Speedtest.Decoder`:** Replaced `SweetXml` / `:xmerl` XPath parsing with `Jason` JSON decoding while preserving existing return map structures and public functions (`client/1`, `server/1`, `server_config/1`, `config/1`, `download/1`, `upload/1`, `latency/1`, `license/1`, `odometer/1`, and `socket_*/1`).
- **`Speedtest`:**
    - Updated `@config_url` and `@server_urls` to `/api/js/config-sdk` and `/api/js/servers`.
    - Added `Accept: application/json` to default headers and enabled `follow_redirect: true` on download and upload requests.
    - Added `json_body?/1` response validation to reject non-JSON payloads (such as HTML fallback pages) before decoding.
- **`Speedtest.Result`:**
    - Updated `@share_url` to `https://speedtest.net` and added `Content-Type: application/x-www-form-urlencoded` and `follow_redirect: true`.
    - Converted `download` and `upload` values from Mbps to Kbps (`* 1000`) when building the share payload.
- **Test Suite:** Updated `Speedtest.DecoderTest`, `Speedtest.RunTest`, and `Speedtest.ResultShareTest` fixtures and assertions from XML to JSON and aligned URL expectations with the new endpoints.

### Fixed
- **`:xmerl` `:expected_markup` crash:** Resolved fatal XML parsing errors caused by requests hitting `https://speedtest.net` or deprecated `.php` endpoints returning HTML (`<!doctype html>`).
- **Result Share Image URL (`Speedtest.Result.share/1`):** Fixed missing string interpolation and path formatting so shared results return `https://speedtest.net<id>.png` instead of `https://speedtest.net{result_id}.png`.

## - Previous Release
- Initial Hex release of `speedtest`.
