# SPDX-License-Identifier: AGPL-3.0-or-later
from pathlib import Path
import re
ROOT = Path(__file__).parents[1]

def text(path): return (ROOT / path).read_text()

def test_required_artifacts_exist():
    required = ["Package.swift", "project.yml", "LICENSE", "NOTICE", "README.md",
      "docs/FEATURE_MATRIX.md", "docs/VERIFICATION.md",
      "Sources/HealthCore/APIEndpoint.swift", "Sources/HealthCore/Models.swift",
      "Sources/HealthCore/Validation.swift", "Sources/HealthCore/UnitConverter.swift",
      "HealthJournal/App/HealthJournalApp.swift", "HealthJournal/Services/HealthAPIClient.swift",
      "HealthJournal/Services/KeychainStore.swift", "HealthJournal/Views/RootView.swift"]
    assert not [p for p in required if not (ROOT / p).is_file()]

def test_api_endpoint_coverage():
    source = text("Sources/HealthCore/APIEndpoint.swift") + text("HealthJournal/Services/HealthAPIClient.swift")
    fragments = ["configuration", "daily-notes", "daily-values", "entries", "measurements",
                 "routines", "goals", "progress", "statistics", "views", "cloud/capabilities"]
    assert not [x for x in fragments if x not in source]
    for verb in ["GET", "POST", "PUT", "DELETE"]: assert verb in source

def test_security_contract():
    client = text("HealthJournal/Services/HealthAPIClient.swift")
    keychain = text("HealthJournal/Services/KeychainStore.swift")
    validation = text("Sources/HealthCore/Validation.swift")
    assert "OCS-APIRequest" in client and "Basic " in client
    assert "kSecClassGenericPassword" in keychain
    assert "URLSessionConfiguration.ephemeral" in client
    assert "https" in validation.lower()
    for token in ["percentEncodedUser", "percentEncodedPassword", "query", "fragment", "port"]: assert token in validation

def test_typed_list_filters_and_statistics_periods():
    source = text("Sources/HealthCore/APIEndpoint.swift")
    for token in ["metricKey", "from", "to", "period", "date", "last_30_days", "this_week", "last_year"]: assert token in source

def test_typed_models_match_openapi_and_capabilities():
    source = text("Sources/HealthCore/Models.swift")
    for token in ["metricKey", "allowedOptions", "aggregation", "heightCm", "heightDisplayUnit", "dateOfBirth", "growthReferenceSex", "checkInEnabled", "checkOutEnabled", "StatisticsSummary", "StatisticsGoalSegment", "Double?"]:
        assert token in source
    assert "public var content:String?" in source

def test_all_fallback_metrics_are_present():
    models = text("Sources/HealthCore/Models.swift")
    keys = ["stress","energy","mood","hydration","break","temperature","oxygen_saturation",
      "blood_glucose","pulse","blood_pressure","weight","body_fat","waist","hip",
      "muscle_percentage","sins","steps","kilocalories","fruit","job_satisfaction"]
    assert len(keys) == 20
    assert not [k for k in keys if f'"{k}"' not in models]

def test_ui_is_substantial_and_navigable():
    ui = "\n".join(p.read_text() for p in (ROOT / "HealthJournal/Views").glob("*.swift"))
    for item in ["TabView", "Journal", "Records", "Goals", "Statistics", "Settings", "Quick Entry", "Chart"]:
        assert item in ui
    assert len(ui.splitlines()) >= 500

def test_localization_and_accessibility():
    ui = "\n".join(p.read_text() for p in (ROOT / "HealthJournal").rglob("*.swift"))
    assert "accessibilityLabel" in ui
    assert (ROOT / "HealthJournal/Resources/Localizable.xcstrings").is_file()

def test_swift_tests_cover_core_contracts():
    tests = "\n".join(p.read_text() for p in (ROOT / "Tests/HealthCoreTests").glob("*.swift"))
    for item in ["APIEndpoint", "OCS", "UnitConverter", "Validation", "URLRequest"]: assert item in tests
    assert tests.count("func test") >= 15

def test_capabilities_gate_before_keychain_save():
    models=text("Sources/HealthCore/Models.swift");client=text("HealthJournal/Services/HealthAPIClient.swift");store=text("HealthJournal/App/AppStore.swift")
    for token in ["apiVersions", "features", "goalTargets", "capabilities()", "contains(\"2\")"]: assert token in models+client+store
    assert store.index("await candidate.capabilities") < store.index("keychain.save")

def test_service_safety_and_schema_corrections():
    client = text("HealthJournal/Services/HealthAPIClient.swift")
    store = text("HealthJournal/App/AppStore.swift")
    for token in ["appPassword", "wipe", "success", "ConfigurationUpdate", "heightUnit", "metricKey", "sendRaw", "GoalTarget", "LocalDayRange"]:
        assert token in client + store + text("Sources/HealthCore/Models.swift")
    assert 'String(data:' not in client
    assert 'remote-wipe' not in client
    assert "RawBody" not in store

def test_login_flow_remote_wipe_and_removal():
    source = "\n".join(p.read_text() for p in (ROOT / "HealthJournal").rglob("*.swift"))
    for token in ["index.php/login/v2", "application/x-www-form-urlencoded", "core/apppassword", "index.php/core/wipe/check", "UIApplication.shared.open"]:
        assert token in source

def test_encrypted_idempotent_outbox():
    source = text("HealthJournal/Services/EncryptedOutbox.swift")
    for token in ["operationId", "UUID", "NSFileProtectionComplete", "AES.GCM", "KeychainStore"]:
        assert token in source
    tests = "\n".join(p.read_text() for p in (ROOT / "Tests/HealthCoreTests").glob("*.swift"))
    assert "OutboxOperation" in tests and "testOutbox" in tests

def test_no_hardcoded_credentials_or_general_payload_persistence():
    source = "\n".join(p.read_text() for p in (ROOT / "HealthJournal").rglob("*.swift"))
    assert "UserDefaults.standard.set" not in source
    assert not re.search(r'password\s*=\s*"[^\"]+"', source, re.I)

def test_reviewed_sync_and_api_contracts():
    store = text("HealthJournal/App/AppStore.swift")
    client = text("HealthJournal/Services/HealthAPIClient.swift")
    outbox = text("HealthJournal/Services/EncryptedOutbox.swift")
    endpoints = text("Sources/HealthCore/APIEndpoint.swift")
    journal = text("HealthJournal/Views/JournalView.swift")
    assert "sendValidatedRaw" in client and "OCSMetadataResponse" in client
    assert "allEntries" in client and "nextCursor" in client and "limit:200" in store
    assert "GoalPeriod" in endpoints and "period.rawValue" in endpoints
    assert "NWPathMonitor" in store and "flushing" in store
    assert "loadError" in outbox and "persist(proposed)" in outbox
    assert journal.rindex("outbox.enqueue") < journal.rindex("flushOutbox")

def test_website_navigation_clone_and_note_autosave():
    journal = text("HealthJournal/Views/JournalView.swift")
    statistics = text("HealthJournal/Views/StatisticsView.swift")
    assert 'accessibilityLabel("Today")' in journal
    assert 'accessibilityLabel("Next day")' in journal
    assert "noteSaveTask" in journal and "scheduleNoteAutosave" in journal
    assert 'Button("Clone")' in statistics
