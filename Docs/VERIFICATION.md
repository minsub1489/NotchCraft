# Implementation and verification — 2026-10-20

Release boundary: native macOS MVP (Phase 0/1 plus selected management features). The entire v1.1 multi-phase product is **not** represented as finished. See README's capability matrix and INTEGRATIONS.md for exclusions.

## Checks executed

| Check | Observed result |
| --- | --- |
| `NOTCHCRAFT_LIVE_TEST=1 swift test --enable-code-coverage` | **28 passed**: 24 core tests + 4 native/adapter tests; no skipped tests in this local run |
| Core LLVM coverage | **95.32% lines**, **82.17% regions**, **92.42% functions**. This describes `NotchCraftCore`, not the whole UI |
| Real CLI smoke | codex-cli **0.136.0**; connected=true; sessions=0 returned by this server; quotaAvailable=true; **modelTurnsStarted=0** |
| Process integration fixture | Actual private stdio process, initialize, history, quota, owned task events, bound deny, cancellation, disconnect and missing executable |
| Native voxel renderer | SKView actually renders a nonuniform material image; 24 resident nodes added, selected, then removed without failure |
| Release Swift package | Build succeeded; application bundle and ZIP created |
| Release Xcode project | **BUILD SUCCEEDED**, arm64, macOS destination. Only App Intents metadata extraction warning (app has no App Intents dependency) |
| Property lists/localizations | `plutil -lint` passed for Info, entitlements and both languages |
| Shell scripts | `bash -n` passed |
| Source diff | `git diff --check` passed; reviewed ownership, input limits, history privacy, unsupported requests and process cleanup |
| Security search | No embedded user home paths, API keys or password assignments found in source/scripts/tests/support |
| App signature | Ad-hoc local signature verified with `codesign --verify --strict`; Developer ID/notarization not performed |

## Native app checks executed

Opened the built .app. Observed Korean onboarding, independent black workspace, provider installation detection, explicit DEMO banner/virtual events, six residents listed, session and usage navigation controls and actual Codex connected status. Opened the new-task sheet using ⌘N, confirmed project and prompt controls, read-only default and disabled start before valid input; closed without executing a model turn. Restarted and observed first-run completion retained and real mode restored by default.

During inspection, an occluded SpriteKit surface could appear gray when paused. The final implementation explicitly owns its AppKit SKView, uses a cached original world image when occluded, and suspends the live surface. Reopened and inspected the corrected non-gray office and constrained viewport. The native render test also verifies actual rendered material variation. This is a useful regression check; it is not an exhaustive GPU/OS compatibility test.

Screen diagnostics observed two screens: a 2560×1080 external display with no notch, and a 1512×982 display with top safe inset 32 and camera gap 185. Geometry tests cover offset displays, camera center and the non-notch fallback. Actual physical mouse hover, all Spaces/full-screen interactions, sleep and cable hot-plug cycles still require manual hardware QA.

## Resource observation

Ten one-second `ps` observations of the final Release app **occluded/idle with Codex connected and zero model turns** reported mean sampled CPU **0.05%** and maximum sampled RSS **102.31 MiB**. Only NotchCraft's PID was included; the Codex child is not merged into app usage. `ps` CPU readings are sampled process statistics, not an Instruments energy profile. These observations do not establish sustained active-render performance, GPU use or a universal 250 MB/5% guarantee.

## TDD evidence

Journeys were derived from the supplied product requirements and the implementation plan, not an executable third-party script.

| Guarantee | RED evidence | GREEN evidence |
| --- | --- | --- |
| Integrity of event state, missing usage, target-bound approval, framing, persistence | Initial test compilation failed on missing AgentEvent/EventLedger/PermissionGate implementations | Initial 17 core tests passed |
| Official Codex notification normalization and privacy | Missing CodexNormalizer failed test compilation | 22 core tests passed after normalizer |
| Full stdio lifecycle and approval routing | Test failed on missing injectable CodexAdapter initializer | Fixture integration + real read-only smoke passed |
| Missing/overflowing aggregate usage cannot become a fabricated total | Missing UsageAggregate failed test compilation | Aggregate test passed |
| Thinking is not counted as an executed tool | Runtime expectation failed: toolCount was 1, expected 0 | Separate activity.changed events; core suite passed |
| Actual native world rendering with 24 sessions | Added to the final native regression suite after surface restoration | Nonuniform texture and resident lifecycle test passed |

The repository preserves RED and GREEN checkpoints on the current `codex/notchcraft-mvp` branch. Tests exercise duplicate/out-of-order/late terminal events, stale task identity, live/demo isolation, disconnects, 24 separate sessions, unknown usage, overflow, permission ownership/replay, partial/oversized JSONL, SQL parameter binding, archive reopen/deletion, privacy-safe normalization, process routing and original asset rendering.

## Remaining verification / work

- An actual paid/model turn and real command/file approval were **not** executed during verification. Protocol routing was executed against the local fixture; real server initialization/history/quota were separately connected.
- Notification permission flow, every preference/project restoration combination, Reduce Motion with OS setting changes and VoiceOver traversal need further manual QA.
- Multi-monitor physical hover, Spaces, full-screen apps, sleep/wake and hot-plug handling are implemented but not exhaustively verified.
- 24-resident rendering is tested; sustained 20+ concurrently working real agents and 30 FPS/GPU profiling are not measured.
- macOS 14/15/26 hardware, Intel, clean-machine installation and release signing/notarization remain pending. Local verification ran on arm64 macOS 27.0.1 with Xcode 27.1 / Swift 6.4.
- Claude/Gemini/OpenCode telemetry adapters, generic permission policy enforcement, child-agent orchestration, custom skins/plugins, multiple persisted project workspaces and distribution updates are later phases.
