# NotchCraft 0.1.1 — 2026-10-20

## Changes and evidence

- Account allowance now names both consumed and remaining percentages. The main bar represents remaining allowance, matching Codex's display convention. Weekly and five-hour windows have localized titles. Separate named limit buckets are retained without repeating the legacy bucket.
- The usage view refreshes immediately, polls at 15-second intervals and accepts official quota notifications. History refreshes independently every 30 seconds. Invalid updates cannot replace a valid snapshot; disconnected, expired or failed refreshes show the last value as stale.
- During native UI inspection, the app showed **32% remaining / 68% used** and **89% remaining / 11% used**, identical to the desktop usage tool's observed response at that comparison. Later reads changed as this development chat consumed quota. Earlier sequential probes differed by a few points before converging; no claim of zero backend propagation delay is made. No account IDs, credentials or raw account responses are stored in this report.
- Residents now have separate torso, head, arm, leg and tool nodes. Planting emits seeds after a bend; mining has anticipation, contact, fragments and recovery; patrol has steps, turns and pauses to scan; reading holds an open book and turns pages. Building, testing and automation have separate poses and props. Travel uses walking, selection does not reset the clip, and observed non-working states stop work. Reduced Motion freezes decorative movement.
- The black notch panel begins below both the menu bar and physical camera. Concave shoulders connect its silhouette to the housing; no label or button occupies the menu bar. Native NSPanel frame tests cover collapsed and expanded frames on every attached screen.

The [official App Server field definitions](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt) were checked with the installed CLI schema. `usedPercent` means consumed usage; `windowDurationMins` is the window length. The app derives the complement only when a valid consumed percentage is provided.

## Verification

| Check | Result |
| --- | --- |
| `NOTCHCRAFT_LIVE_TEST=1 NOTCHCRAFT_MOTION_GIF="$PWD/build/motion-preview.gif" swift test --enable-code-coverage` | **41 passed**: 33 core and 8 native/adapter tests, including the opt-in live read and actual motion rendering |
| Core coverage | **95.52% lines**, **85.20% regions**, **92.11% functions**; this describes the core module, not the entire UI |
| New quota / motion logic | AccountQuota 94.59% line coverage; WorkerMotion 93.46% line coverage |
| Process integration | Local JSONL fixture verifies changed values on consecutive reads and real quota-notification routing, alongside the prior task/approval lifecycle |
| Real Codex smoke | Connected; account quota available; zero sessions returned; **modelTurnsStarted=0** |
| Native geometry | Collapsed and expanded NSPanel frames stay below the menu/camera on the connected 2560×1080 external and 1512×982 notched screens |
| Native renderer | 24 residents render and can be removed; working limbs move, approval waiting stops the tool, reading shows its book |
| Motion artifact | `build/motion-preview.gif`: 84 actual SpriteKit frames at 12 FPS, using the same worker rig as the app. Explicitly labeled DEMO PREVIEW |
| Xcode Release | **BUILD SUCCEEDED**, arm64/macOS; existing App Intents metadata warning only |
| Release packaging | Swift Release build and 0.1.1 ZIP created; `codesign --verify --strict` passed; no test fixtures in the app bundle |
| Source/resources | Swift strict concurrency compilation, `git diff --check`, property-list/localization validation and shell syntax checks passed |
| Security review | No credentials added, no auth-file access, no new dependencies or external upload. Account snapshots stay in memory; approval/ownership boundaries are unchanged |

RED checkpoints are preserved in `f2cb622` (quota, motion and notch regressions) and `08a742e` (actual monitoring/search command mapping). Initial core GREEN is `e0208b1`; native integration and release changes follow it.

The packaged app was reopened, its 0.1.1 footer and actual quota display were observed, and the compact notch screenshot showed the full avatar/count/status row without clipping. The nonactivating panel's physical hover could not be driven by the available UI automation surface, so its full hover journey remains a hardware QA item.

## Limits of this verification

Actual model work was not started to consume the user's allowance. Real App Server reads and local fixture events were tested separately. The animation GIF is a diagnostic preview, not evidence that AI tasks ran. Native frame tests verify placement on connected hardware; physical mouse hover, every full-screen/Spaces/menu-autohide combination and cable hot-plug cycles still need manual QA. Intel and older macOS versions were not available in this run. Backend values may lag a read briefly; the app displays observed values with their refresh time rather than guessing changes.
