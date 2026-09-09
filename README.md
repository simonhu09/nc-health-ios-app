# Health Journal for Nextcloud

A native iOS 17+ SwiftUI client for Nextcloud Health v3 API v2. It provides a date journal, daily notes and values, event and measurement editing, check-in/out routines, goal management, statistics charts, saved views, server-driven metric settings, and an offline Quick Entry queue.

The pinned source contract is Nextcloud Health 3.2.0, compatible with Nextcloud 33–35. Account setup still validates the deployed server's Health API-v2 capability before enabling the app.

## Build

1. Install Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Run `xcodegen generate`.
3. Open `HealthJournal.xcodeproj`, choose a signing team, and build the `HealthJournal` scheme.
4. Tests: `swift test` for portable core tests, and `xcodebuild test -scheme HealthJournal -destination 'platform=iOS Simulator,name=iPhone 15'` for Apple integration tests.

No third-party runtime dependencies are used.

## Setup

Enter the HTTPS URL of your Nextcloud. **Login Flow v2 is recommended**: the app posts to `/index.php/login/v2`, opens the returned approval URL in the system browser, polls the token endpoint, and saves the returned login name and app password in iOS Keychain. See the [official Login Flow v2 documentation](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/LoginFlow/index.html).

Manual setup remains available: enter the login name and a dedicated app password from Nextcloud **Personal settings → Security**. Never enter the normal account password.

Account removal first asks Nextcloud to revoke the current app password with `DELETE /ocs/v2.php/core/apppassword`, then always erases local credentials and the outbox. Following authentication failures, the app checks the [Nextcloud Remote Wipe protocol](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/RemoteWipe/index.html); a wipe directive erases local state before best-effort acknowledgement.

## Privacy and security

- HTTPS is mandatory. Debug builds permit HTTP only for loopback localhost. URL credentials, query strings, fragments, and invalid ports are rejected; valid custom HTTPS ports are supported.
- Credentials and the offline encryption key use Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Networking uses an ephemeral `URLSession` with no URL cache.
- Ordinary notes, metrics, records, statistics, and current values remain in memory and are not persisted.
- Quick Entry persists each user-created pending operation before attempting transport, then automatically replays it when connectivity returns. The file is AES-GCM encrypted with a random Keychain-held key and marked `NSFileProtectionComplete`.
- Entry and measurement creates contain a stable UUID v4 `operationId` across retries. Daily-value retries are idempotent PUTs to a metric/date identity.
- Quick Entry deliberately does not show history or current values. A queue-only toggle lets the user defer synchronization deliberately.

## Source and API

The implementation targets `{server}/ocs/v2.php/apps/health/api/v2/`, uses Basic authentication with an app password, and sends `OCS-APIRequest: true`. API behavior, schemas, and the 20-metric fallback catalog were derived for interoperability from the [Nextcloud Health source and OpenAPI document](https://github.com/nextcloud/health). Runtime configuration/capabilities remain authoritative.

License: AGPL-3.0-or-later. See `LICENSE` and `NOTICE`.
