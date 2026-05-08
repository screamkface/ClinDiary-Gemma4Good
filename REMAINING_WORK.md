# Remaining Work

## Current App Work

### Completed
- Fixed the vaccination add/edit flow crash when dismissing the form with back by moving it to a dedicated bottom sheet that owns its controllers safely.
- Added a regression test for closing the vaccine form with back.
- Redesigned Ask Files as a chat-style experience with message bubbles, typing animation, simple scope pills and sources shown below the answer.
- Removed the duplicate Ask Files form/card by moving the input directly into the chat panel.
- Added a glowing AI-style Ask Files entry button in the Documents archive.
- Updated Gemma Center so the chat section fits in the first viewport on entry and the supporting tools use the same softer visual language.
- Simplified the Documents archive, upload, detail and query history copy by removing repeated local/on-device/provider/model wording from the primary UI.

### Still Missing
- Review the remaining document review/manual-review screens for the same child-friendly visual language.
- Decide whether Ask Files history should also become a full chat transcript rather than expandable cards.

### Known Bugs
- No known blocking bug from the vaccine back flow after the regression test.

### Next Recommended Step
- Run the full mobile test suite before release builds, then continue simplifying secondary Documents screens.

## Completed
- OpenCode project configuration scaffolded.
- Custom OpenCode subagents added (review, architect).
- Custom OpenCode slash commands added (continue, check, review).
- OpenCode CLI installed globally and verified (`opencode --version`, `opencode models --refresh`, `opencode mcp list`).
- Project `opencode.jsonc` hardened with repo-specific safe command allowlist.
- Serena MCP template added in disabled mode and Serena analysis subagent created.
- MCP OAuth attempts executed for Context7 and GitHub from CLI.

## Missing
- Add any missing provider logins and verify available models.
- Provide `CONTEXT7_API_KEY` environment variable (currently not set) so Context7 auth is persistent.
- Decide GitHub MCP auth mode (current endpoint reports incompatible OAuth dynamic registration).
- Validate project checks run cleanly in current environment.

## Known Issues
- `opencode mcp auth context7` reports success but `opencode mcp auth ls` still reports unauthenticated without `CONTEXT7_API_KEY` set.
- `opencode mcp auth github` fails with: `Incompatible auth server: does not support dynamic client registration`.

## Next Recommended Step
- Set `CONTEXT7_API_KEY`, re-run `opencode mcp list`, and optionally enable GitHub MCP only when needed.
