# Mac App Feature Checklist

## 1. App Foundation

- [x] Create macOS app project in Swift / SwiftUI
- [x] Add menu bar app mode
- [ ] Add background agent lifecycle
- [ ] Add launch-at-login support
- [x] Add app settings window
- [ ] Add onboarding flow
- [x] Add local logging/debug console
- [ ] Add feature flags for experimental surfaces
- [ ] Add crash/error reporting, ideally opt-in
- [ ] Decide distribution path: Developer ID + notarization, likely outside Mac App Store

## 2. Permissions & Onboarding

- [x] Request Accessibility permission
- [x] Detect whether Accessibility permission is granted
- [x] Deep-link user to macOS Privacy & Security settings
- [ ] Request Screen Recording permission for screenshot memory
- [ ] Explain why each permission is needed
- [ ] Add “test permissions” step in onboarding
- [ ] Show active recording/context indicator when screenshot memory is enabled
- [x] Add one-click pause/resume
- [ ] Add app denylist during onboarding
- [ ] Add sensitive-app defaults: password managers, banking, private browsing, terminals maybe opt-in

## 3. Focus & Input Field Detection

- [x] Track currently focused app
- [x] Track currently focused window
- [x] Track currently focused accessibility element
- [x] Detect editable text fields
- [x] Read field role/type via Accessibility APIs
- [x] Read current field value when available
- [x] Read selected text range
- [x] Read cursor/caret range
- [ ] Read surrounding text around cursor
- [x] Detect secure/password fields and disable completions
- [x] Detect unsupported fields and fallback gracefully
- [ ] Maintain per-app compatibility metadata

## 4. Text Context Extraction

- [x] Extract prefix before cursor
- [x] Extract suffix after cursor
- [x] Extract selected text
- [ ] Extract nearby paragraph/sentence boundaries
- [x] Handle empty input fields
- [ ] Handle multiline text fields
- [ ] Handle rich text editors
- [ ] Handle browser textareas/contenteditable fields
- [ ] Handle Electron apps
- [ ] Handle native AppKit text fields
- [ ] Handle web apps like Gmail, Slack, Notion, Google Docs, Linear
- [ ] Add context truncation policy
- [ ] Add normalization for whitespace and hidden characters

## 5. User Activity Tracking

- [ ] Track app switches
- [ ] Track window switches
- [x] Track focus changes
- [x] Track mouse clicks
- [x] Track keypress timing without storing raw keys unnecessarily
- [x] Track typing bursts
- [x] Track pause-after-typing events
- [ ] Track “reply/compose/comment” style UI transitions when inferable
- [x] Track accepted suggestions
- [x] Track dismissed suggestions
- [ ] Track overwritten suggestions
- [x] Maintain short-lived local event timeline

## 6. Screenshot Memory

- [ ] Implement ScreenCaptureKit capture pipeline
- [ ] Capture active display or active window
- [ ] Capture on fixed interval
- [ ] Capture on event triggers: app switch, focus change, click, reply/compose transition
- [ ] Add screenshot sampling rate controls
- [ ] Add pause screenshot capture while idle
- [ ] Add app/window denylist
- [ ] Add sensitive-content heuristics
- [ ] Add encrypted short-term screenshot ring buffer
- [ ] Auto-delete raw screenshots after short retention window
- [ ] Store longer-lived structured summaries instead of raw images
- [ ] Add user-facing “clear memory” button
- [ ] Add debugging viewer for local-only captured context

## 7. OCR & Scene Understanding

- [ ] Run Apple Vision OCR on screenshots
- [ ] Extract visible text with bounding boxes
- [ ] Associate OCR text with app/window metadata
- [ ] Associate OCR text with timestamps
- [ ] Deduplicate repeated screenshot text
- [ ] Segment screenshot into coarse UI regions
- [ ] Identify likely active document/email/thread/page
- [ ] Summarize visible scene into compact memory
- [ ] Embed OCR/summaries for retrieval
- [ ] Add optional multimodal model pass for hard cases
- [ ] Avoid sending screenshots to cloud by default
- [ ] Add quality metrics for OCR coverage

## 8. Context Retrieval

- [ ] Build local context store
- [ ] Store recent field states
- [ ] Store recent OCR text
- [ ] Store recent scene summaries
- [ ] Store app/window metadata
- [ ] Add recency-weighted retrieval
- [ ] Add semantic retrieval
- [ ] Add app/window-aware retrieval
- [ ] Retrieve recent visible context when user enters a reply/comment field
- [ ] Avoid screenshot context unless useful
- [ ] Add context budget manager
- [ ] Add final prompt/context inspector for debugging

## 9. Completion Request Pipeline

- [x] Define internal completion request schema
- [x] Include current app/window
- [x] Include field role
- [x] Include prefix/suffix
- [x] Include selected text
- [ ] Include recent edit/action history
- [ ] Include retrieved scene memory
- [ ] Include confidence/uncertainty signals
- [x] Debounce requests during typing
- [x] Cancel stale requests when user continues typing
- [ ] Cache repeated requests
- [ ] Add timeout budget
- [x] Add fallback when model is unavailable

## 10. Local Model Runtime

- [ ] Choose first runtime: MLX, llama.cpp, or both
- [ ] Package small local model
- [ ] Add model download manager
- [ ] Add model quantization support
- [ ] Add model warmup
- [ ] Keep inference worker alive in background
- [ ] Stream partial predictions internally
- [ ] Add latency instrumentation
- [ ] Add memory usage instrumentation
- [ ] Add battery/thermal guardrails
- [ ] Add “local only” mode
- [ ] Add optional cloud inference mode later
- [ ] Add model versioning

## 11. Prompting / Model Interface

- [ ] Define prompt format for text-only completions
- [ ] Define prompt format for screenshot-aware completions
- [x] Define output schema
- [x] Support plain inline continuation
- [x] Support no-suggestion output
- [x] Validate model output before showing
- [ ] Reject suggestions that conflict with cursor state
- [ ] Reject suggestions that are too long
- [ ] Add app-specific prompt hints
- [ ] Add user tone/style preferences later

## 12. Suggestion Rendering

- [x] Compute caret position from Accessibility APIs
- [x] Render ghost text overlay near caret
- [ ] Match font size when possible
- [ ] Match line height when possible
- [ ] Match text direction/layout when possible
- [ ] Handle scrolling fields
- [x] Handle multiline ghost text
- [x] Hide suggestion when cursor moves
- [x] Hide suggestion when user types incompatible text
- [x] Hide suggestion on focus loss
- [x] Add anchored popover fallback
- [ ] Add command palette/manual fallback
- [ ] Add per-app rendering strategy

## 13. Suggestion Acceptance

- [ ] Accept suggestion with Tab
- [x] Accept suggestion with configurable hotkey
- [ ] Accept word-by-word with modifier hotkey
- [ ] Dismiss with Escape
- [x] Dismiss on continued typing
- [x] Insert accepted text through Accessibility when possible
- [x] Fall back to simulated paste/keyboard events when necessary
- [x] Preserve clipboard when using paste fallback
- [ ] Verify inserted text matches expected output
- [x] Handle selected-text replacement
- [ ] Handle partial acceptance
- [x] Log accept/reject signal locally

## 14. Compatibility Matrix

- [x] Native macOS text fields
- [ ] Safari textareas
- [ ] Chrome textareas
- [ ] Gmail compose/reply
- [ ] Apple Mail
- [ ] Slack
- [ ] Discord
- [ ] Notion
- [ ] Google Docs
- [ ] Linear
- [ ] GitHub comments/issues/PRs
- [ ] VS Code / Cursor
- [ ] Terminal apps, likely disabled or manual-only initially
- [x] Password fields, always disabled
- [ ] Private/incognito windows, disabled by default

## 15. Privacy & Security

- [x] Local-first default
- [ ] Explicit opt-in for screenshot memory
- [ ] Visible capture indicator
- [ ] App denylist
- [ ] Domain denylist for browsers
- [ ] Sensitive-field detection
- [ ] Raw screenshot retention limit
- [ ] Encrypted local storage
- [ ] Clear local memory control
- [ ] No training upload by default
- [ ] Separate opt-in for telemetry
- [ ] Separate opt-in for model improvement
- [ ] Redact emails, phone numbers, tokens, passwords where possible
- [ ] Add privacy audit logs
- [ ] Add “what context was used?” viewer

## 16. Settings UI

- [x] Enable/disable completions globally
- [ ] Enable/disable screenshot memory
- [x] Configure hotkeys
- [ ] Configure model
- [ ] Configure local/cloud mode
- [ ] Configure capture frequency
- [ ] Configure app allowlist/denylist
- [ ] Configure browser domain denylist
- [ ] Configure retention period
- [ ] Configure suggestion aggressiveness
- [ ] Configure max suggestion length
- [ ] Configure style/tone preferences
- [ ] Configure launch at login

## 17. Observability & Debugging

- [x] Local event log
- [ ] Completion latency histogram
- [ ] Model inference latency
- [ ] Context retrieval latency
- [ ] OCR latency
- [ ] Render success/failure logs
- [ ] Per-app compatibility logs
- [ ] Suggestion lifecycle tracing
- [ ] Debug overlay for caret bounds
- [ ] Debug overlay for focused element
- [ ] Debug inspector for final model prompt
- [ ] Export anonymized bug report option

## 18. Evaluation Metrics

- [ ] Suggestion show rate
- [ ] Suggestion acceptance rate
- [ ] Characters saved
- [ ] Latency p50/p90/p99
- [ ] Wrong-surface suggestion rate
- [ ] Stale-context suggestion rate
- [ ] Screenshot-grounded suggestion success rate
- [ ] Dismissal rate
- [ ] Partial acceptance rate
- [ ] Per-app success rate
- [ ] Memory usage
- [ ] Battery impact
- [ ] User trust/privacy complaints

## 19. MVP Scope

- [x] Menu bar app
- [x] Accessibility permission onboarding
- [x] Detect active text field
- [x] Read prefix/suffix for supported fields
- [x] Generate local or mocked completion
- [x] Render anchored popover suggestion
- [x] Accept suggestion with hotkey
- [x] Insert accepted text
- [x] Add local logs
- [ ] Support 3–5 target apps first: Safari/Chrome Gmail, Apple Mail, Slack, native text fields

## 20. MVP+ Screenshot Context

- [ ] Request Screen Recording permission
- [ ] Capture active window on focus/click transitions
- [ ] Run Vision OCR
- [ ] Store recent OCR text in memory
- [ ] Retrieve recent OCR when user focuses reply/comment field
- [ ] Feed retrieved context into completion prompt
- [ ] Test email-read → reply-suggestion flow
- [ ] Add visible screenshot-memory indicator
- [ ] Add clear-memory button
- [ ] Add denylist for sensitive apps/domains

## 21. Later Training/Data Features

- [ ] Log opt-in interaction traces
- [ ] Store starting state, not raw final user text by default
- [ ] Generate teacher completions from stronger model
- [ ] Build synthetic email/reply/comment/form datasets
- [ ] Build screenshot-grounded synthetic workflows
- [ ] Fine-tune Gemma with LoRA/QLoRA
- [ ] Add preference tuning from accept/reject pairs
- [ ] Build offline eval suite
- [ ] Run shadow-mode evaluation
- [ ] Add model rollback/versioning

## 22. Major Known Risks

- [ ] Inline ghost text will not work everywhere
- [ ] Some apps expose poor Accessibility metadata
- [ ] Web rich-text editors may need custom handling
- [ ] Screenshot memory creates serious privacy burden
- [ ] OCR may miss hidden/offscreen context
- [ ] Local model latency may be too high without aggressive optimization
- [ ] Simulated text insertion may be brittle
- [ ] Sandboxed Mac App Store distribution is likely not viable
- [ ] iOS version cannot mirror macOS system-wide behavior with public APIs
