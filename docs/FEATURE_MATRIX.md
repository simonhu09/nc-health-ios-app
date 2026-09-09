# Feature matrix

All rows target Nextcloud Health API v2. “UI” means a navigable screen/form exists; “Core” means typed endpoint/request/model coverage exists.

| Area | API | UI | Core | Notes |
|---|---|---:|---:|---|
| Capabilities | `GET /ocs/v2.php/cloud/capabilities` | Setup | Yes | Dynamic server metric definitions; 20-key fallback |
| Configuration | `GET/PUT configuration` | Settings | Yes | Typed profile, metric enablement, routine switches, units, note search |
| Daily note | `GET/PUT daily-notes/{date}` | Journal | Yes | Nullable missing note; debounced autosave plus explicit save |
| Daily values | `GET daily-values?date` | Journal/Records | Yes | Date list |
| Daily value upsert | `PUT daily-values/{metricKey}/{date}` | Daily-value form/Quick Entry | Yes | Unit-aware |
| Daily value delete | `DELETE daily-values/{metricKey}/{date}` | Records | Yes | Swipe action |
| Entries list | `GET entries` | Journal/Records | Yes | Typed metric/from/to/cursor/limit query, cursor model |
| Entries create/update/delete | `POST entries`; `PUT/DELETE entries/{id}` | Reusable entry form | Yes | UUID operation ID on creates |
| Measurements list | `GET measurements` | Journal/Records | Yes | Typed half-open from/to query |
| Measurements C/U/D | `POST measurements`; `PUT/DELETE measurements/{id}` | Reusable form | Yes | Composite blood pressure |
| Check-in/out | `POST routines/{check-in|check-out}` | Settings → Routines | Yes | Config-driven, atomic mixed payload |
| Goals list/create | `GET/POST goals` | Goals | Yes | Uses server target registry |
| Goals update/delete | `PUT/DELETE goals/{id}` | Reusable goal form | Yes | Active/reminders fields |
| Goal progress | `GET goals/progress` | Goals | Yes | Typed period/date query |
| Statistics | `GET statistics?period&metrics` | Charts and summaries | Yes | Exact 8 periods, line charts, stacked event subseries bars, nullable composite series, goal overlays |
| Saved views | CRUD `statistics/views` | Statistics | Yes | Create, apply, edit, clone, delete |
| Login Flow v2 | `POST /index.php/login/v2`; token polling | Setup | Yes | Recommended system-browser flow; 404-only polling |
| Manual app password | Basic auth | Setup fallback | Yes | Keychain only |
| Account removal | `DELETE /ocs/v2.php/core/apppassword` | Settings | Yes | Local erasure is attempted even if revocation fails; failures are surfaced |
| Remote wipe | `/index.php/core/wipe/check`, `/success` | Automatic | Yes | Purge precedes acknowledgement |
| Offline Quick Entry | Local encrypted outbox | Quick Entry | Yes | Queue-first, category-aware, automatic network replay, OCS-validated removal; no history/current values |

## Known limitations

- The server remains the source of truth; the app intentionally provides no offline browsing of fetched health history.
- Quick Entry supports small JSON operations, not attachments or unbounded queues.
- Push notifications are not part of Health API v2; reminder policy is managed on the server.
- Xcode/iOS SDK compile, simulator interaction, Keychain, Data Protection, CryptoKit file round-trip, Charts rendering, Dynamic Type audit, VoiceOver audit, Login Flow browser handoff, and a live Nextcloud integration test require macOS/iOS and are not verified on this Linux host.
