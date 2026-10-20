# Official integration boundaries

Research date: 2026-10-20. Evidence: installed `codex-cli 0.136.0`, its own `app-server generate-ts` output, and the official references below. No unofficial authentication or protected-protocol reverse engineering is used.

## Codex

[Official App Server](https://developers.openai.com/codex/app-server/), [security](https://developers.openai.com/codex/security/).

Use JSONL over a private process's stdin/stdout: initialize → initialized → requests. Supported local calls used here: thread/list, thread/start, turn/start, turn/interrupt, account/rateLimits/read. `useStateDbOnly:true` prevents discovery from invoking the default rollout scan-and-repair flow. The first 50 recent interactive histories are displayed.

Own-runtime notifications drive activity. Actual command/file approvals are server requests with their own JSON-RPC ID, bound to provider, adapter, session and turn. Only `accept`/`decline` are offered. Unsupported request methods return a protocol error and surface a message; users can cancel and run the task in the original CLI. No generic session pause/resume API is claimed.

A separate App Server cannot be assumed to observe another Desktop/CLI process's loaded threads. This runtime-boundary limitation follows from the official protocol's per-server loaded-thread model; arbitrary Desktop attachment was not verified. External discovery therefore remains read-only/unobserved. The app never resumes an external history to pretend it has live telemetry.

Current web documentation is ahead of the installed CLI: account/usage/read, thread/turns/list and thread/items/list are not in this local schema and are not invoked. Quota windows represent account quota, not task percentage or API money. Missing token/billing/remaining-limit values stay absent.

## Other providers — research only, not connected

- [Claude Code Hooks](https://code.claude.com/docs/en/hooks): opt-in hooks can provide lifecycle and tool events. Async observational hooks do not supply generic control of an arbitrary terminal session. Installation/config changes were not performed.
- [Gemini CLI Hooks](https://geminicli.com/docs/hooks/reference/): command stdin JSON and JSON-only stdout; permission notifications are observational. Hook configuration and privacy filtering are required before integration.
- [OpenCode Server](https://opencode.ai/docs/server/) and [SDK](https://opencode.ai/docs/sdk/): an explicitly connected server offers session/status, SSE events, abort and new prompts. Spawning a server is not attachment to an arbitrary existing TUI. The installed OpenCode binary is detected, but no server is started or connected by this release.

## Native UI

[Apple NSScreen](https://developer.apple.com/documentation/appkit/nsscreen), [auxiliaryTopLeftArea](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc), [SpriteKit rendering pause](https://developer.apple.com/documentation/spritekit/skview/ispaused).

Read actual screen frame, visible frame, safeAreaInsets and both auxiliary top areas. Leave the camera gap empty. Use the top center floating panel on non-notch displays. SpriteKit uses a cached original world texture and small animated character nodes; the workspace stops rendering when hidden/occluded. Performance targets require measurements and are not implied by implementation alone.
