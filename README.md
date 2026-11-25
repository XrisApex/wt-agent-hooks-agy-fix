# wt-agent-hooks-agy-fix

Fix for **Microsoft Intelligent Terminal** (`wt-agent-hooks`) breaking **Antigravity CLI (`agy`)** tool calls on Windows while keeping `wtcli.exe` status hook forwarding intact.

> Note: Upstream fixed this in [microsoft/intelligent-terminal#1407](https://github.com/microsoft/intelligent-terminal/pull/1407) (closing [#1406](https://github.com/microsoft/intelligent-terminal/issues/1406)). This script is for users still on older releases (e.g. `0.3.3213.0` / `wt-agent-hooks` `0.1.2`).

## Symptom

When Intelligent Terminal (`Microsoft.IntelligentTerminal`, e.g. `0.3.3213.0`) is installed, every tool call (`read_file`, `run_command`, MCP tools, etc.) in Antigravity CLI (`agy` 1.5.16) fails with:

```text
Encountered error in tool execution: failed to unmarshal result from hook jsonhook__wt-agent-hooks_PreToolUse_0_0 via protojson: {decision:ask}: proto: syntax error (line 1:2): invalid value decision
```

## Root Cause

1. Intelligent Terminal writes `%USERPROFILE%\.gemini\config\plugins\wt-agent-hooks\hooks.json` with a `PreToolUse` command:
   ```text
   powershell.exe -NoLogo -NoProfile -NonInteractive -Command try { wtcli.exe agent-hook --cli-source antigravity --event agent.tool.starting } catch { }; [Console]::Out.WriteLine('{\"decision\":\"ask\"}'); exit 0
   ```
2. `agy` invokes hook commands via `cmd.exe`, which strips the `\"` quotes during command-line parsing, turning `'{\"decision\":\"ask\"}'` into `{decision:ask}` (invalid JSON for `protojson`).
3. Simply returning `{}` in `PreToolUse` is also rejected (`tool call denied by pre-tool hook`), because `agy`'s `PreToolUse` schema expects an explicit `"decision": "allow"`.
4. Renaming the plugin folder to `*.bak` or `*.disabled` inside `.gemini\config\plugins\` or `.gemini\extensions\` does **not** disable it—`agy` scans all subdirectories.

## Fix (Preserves Intelligent Terminal Hook Forwarding)

Run `fix-wt-agent-hooks.ps1` in PowerShell:

```powershell
.\fix-wt-agent-hooks.ps1
```

What it does:
1. Encodes the `PreToolUse` PowerShell snippet with `-EncodedCommand` (UTF-16LE Base64) so `cmd.exe` cannot strip quotes or misparse pipes/redirections.
2. Keeps `wtcli.exe agent-hook --cli-source antigravity --event agent.tool.starting` running (with stdout/stderr suppressed) so Intelligent Terminal still receives tool events.
3. Outputs valid JSON `{"decision":"allow"}` for `agy`.
4. Marks `hooks.json` as Read-Only so Intelligent Terminal does not overwrite the fix on next launch.

After running the script, open a **new** `agy` session.

## Complete Removal (Optional)

If you prefer to disable `wt-agent-hooks` completely instead of patching it, move all `wt-agent-hooks*` folders **outside** `%USERPROFILE%\.gemini\config\plugins\` and `%USERPROFILE%\.gemini\extensions\`.
