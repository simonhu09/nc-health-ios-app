# Verification

## Test-first record

Production implementation began only after `tests/test_structure.py` and `Tests/HealthCoreTests/HealthCoreTests.swift` were created.

### RED — initial contract

Command:

```sh
python3 -m pytest tests/test_structure.py -q
```

Result: exit 1, `7 failed, 1 passed in 0.23s`. Failures were the expected absent core, service, project, UI, resource, and documentation artifacts.

### RED — Login Flow, remote wipe, encrypted outbox

Command:

```sh
python3 -m pytest tests/test_structure.py::test_login_flow_remote_wipe_and_removal tests/test_structure.py::test_encrypted_idempotent_outbox -q
```

Result: exit 1, `2 failed in 0.11s`; Login Flow tokens were absent and `EncryptedOutbox.swift` did not exist.

### RED — typed query/security corrections

Command:

```sh
python3 -m pytest tests/test_structure.py::test_typed_list_filters_and_statistics_periods tests/test_structure.py::test_security_contract -q
```

Result: exit 1, `2 failed in 0.13s`; typed filters and services were not implemented.

### RED — exact schema fixtures

Command:

```sh
python3 -m pytest tests/test_structure.py::test_typed_models_match_openapi_and_capabilities -q
```

Result: exit 1, `1 failed in 0.06s`; `allowedOptions` and the typed schemas were absent.

### RED — service safety corrections

Command:

```sh
python3 -m pytest tests/test_structure.py::test_service_safety_and_schema_corrections -q
```

Result: exit 1, `1 failed in 0.07s`; wipe sequencing, typed update DTO, raw replay, targets, and day range were incomplete.

## GREEN — Linux verification

Run at the repository root. Results below are from the final tree.

```sh
python3 -m pytest tests/test_structure.py -q
```

Final result is recorded after the last execution below.

```sh
PATH=/tmp/swift-6.2.3-RELEASE-ubuntu24.04/usr/bin:$PATH \
LD_LIBRARY_PATH=/tmp/swift-libcompat \
swiftc -typecheck -sdk /tmp/swift-sysroot -module-name HealthCore Sources/HealthCore/*.swift
```

Result: exit 0, no diagnostics.

```sh
PATH=/tmp/swift-6.2.3-RELEASE-ubuntu24.04/usr/bin:$PATH LD_LIBRARY_PATH=/tmp/swift-libcompat \
swiftc -emit-module -enable-testing -sdk /tmp/swift-sysroot -module-name HealthCore \
Sources/HealthCore/*.swift -emit-module-path /tmp/HealthCore.swiftmodule
PATH=/tmp/swift-6.2.3-RELEASE-ubuntu24.04/usr/bin:$PATH LD_LIBRARY_PATH=/tmp/swift-libcompat \
swiftc -typecheck -sdk /tmp/swift-sysroot -I /tmp Tests/HealthCoreTests/*.swift
```

Result: exit 0, no diagnostics; all portable XCTest sources type-check against the emitted core module.

```sh
PATH=/tmp/swift-6.2.3-RELEASE-ubuntu24.04/usr/bin:$PATH LD_LIBRARY_PATH=/tmp/swift-libcompat \
swiftc -frontend -parse HealthJournal/App/*.swift HealthJournal/Services/*.swift \
HealthJournal/Views/*.swift HealthJournalTests/*.swift
```

Result: exit 0 with only the expected Linux parser warning that libc was not supplied to parse-only mode.

```sh
python3 -m pytest tests/test_structure.py -q
```

Result: exit 0, `16 passed in 0.08s`.

```sh
PATH=/tmp/swift-6.2.3-RELEASE-ubuntu24.04/usr/bin:$PATH \
LD_LIBRARY_PATH=/tmp/swift-libcompat swift test
```

Result: exit 127 before compilation: `swift-test: error while loading shared libraries: libxml2.so.2: cannot open shared object file`. The direct portable-core typecheck above is the available Swift verification on this host.

## macOS-only verification gaps

Not claimed here: XcodeGen generation; iOS target compile/link; XCTest execution; mock `URLProtocol`; SwiftUI/Charts previews and simulator navigation; Keychain and `NSFileProtectionComplete`; CryptoKit outbox round-trip; Login Flow system-browser handoff; VoiceOver/Dynamic Type/localization visual audits; account revocation and remote-wipe integration against a real server. Run the README commands on macOS and test against a non-production Nextcloud account before release.
