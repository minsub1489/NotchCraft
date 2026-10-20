# NotchCraft implementation plan

The supplied v1.1 specification is product input. Phase 0 + Phase 1 are the first release boundary; later phases are tracked honestly, not implied complete.

1. Native Swift 6 package and Xcode app, macOS 14+, zero third-party dependencies.
2. Tested event contracts, ordered/deduplicated reducer, permission target binding, bounded JSON-RPC framing, SQLite metadata archive.
3. Codex official app-server over private stdio. Detect installed CLI; read external session metadata; create user-requested sessions; normalize real notifications. Never start a paid/model turn during verification.
4. Original procedural SpriteKit floating voxel island, activity-specific characters, selection, zoom/pan, reduced motion, render suspension.
5. Native black/gold workspace, agent/session detail, actual usage provenance, scoped approvals, explicit demo mode, Korean/English resources, persistent preferences/project.
6. AppKit notch/hover panel and external-screen fallback; screen/wake restoration; buildable app bundle and release scripts.
7. Unit/integration tests, actual read-only Codex smoke check, native UI checks and resource measurements. Record unverified hardware/distribution limits.

Later: verified Claude/Gemini/OpenCode integrations, custom agent bridges/skins, signed/notarized releases, Intel and multi-monitor hardware QA. Detection is distinct from telemetry support.

## Delivered boundary

Native MVP, official Codex adapter, original voxel world, explicit demo, metadata archive, scoped approval UI, usage provenance, onboarding/settings, app/ZIP and Xcode project are implemented. See VERIFICATION.md for actual checks and remaining hardware/model-turn verification. Later phases are intentionally still open; installation detection is not presented as an implemented live adapter.
