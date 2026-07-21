# SECURITY-AUDIT.md

Static security review of the `ube_`-prefixed forks used in the token-optimization
stack. This documents what was inspected, what was found, and the hardening
applied. It is a point-in-time review of the uploaded snapshots — not a guarantee
of upstream safety or of future commits.

- **Auditor:** static review (no code executed; read-only inspection)
- **Date:** 2026-07-21
- **Scope:** the five forked repositories below, as uploaded ZIP snapshots

## Repositories reviewed

| Fork | Upstream | Version at review | Role |
|------|----------|-------------------|------|
| `ube_token-optimizer` | `alexgreensh/token-optimizer` | 5.11.51 | Startup token audit + compression hooks |
| `ube_codegraph` | `colbymchenry/codegraph` (`@colbymchenry/codegraph`) | 1.4.1 | Semantic code index / graph |
| `ube_code-review-graph` | `tirth8205/code-review-graph` | 2.3.7 | Code graph + blast-radius analysis |
| `ube_caveman` | `mattpocock/skills` | 1.1.0 | Skill collection (caveman/handoff/etc.) |
| `ube_skills` | (crafter-station / skills) | n/a | Context-engineering skills (intent-layer) |

> Record the exact reviewed commit SHA for each fork next to its row once pinned
> (see "Hardening applied" → pinning). The ZIP snapshots did not carry `.git`
> history, so SHAs must be captured from your fork after you pin them.

## Method

Inspected, without executing any code:

1. **Install scripts** — `install.sh`, `install.ps1`, and all `package.json`
   lifecycle scripts (`preinstall`/`postinstall`/`prepare`).
2. **Hooks** — every hook config and hook script (Claude Code hooks, git hooks,
   launcher shims).
3. **Network surface** — every hardcoded `http(s)` host in executable code;
   telemetry payload construction.
4. **Dynamic execution** — `eval`, `Function()`, `pickle.loads`, `marshal.loads`,
   `compile()`, `child_process`/`os.system` shelling out.
5. **Credential access** — reads of `.ssh`, `.aws`, `.env`, `.npmrc`, `.netrc`,
   keychains, API-key env vars.
6. **Prompt-injection surface** — skill/instruction Markdown for text that would
   subvert the agent (exfiltrate, disable safety, act without permission).
7. **Obfuscation** — non-ASCII / control bytes flagged by `grep` as "binary".

## Findings

**No malware, backdoors, data exfiltration, or hidden agent-subverting code was
found in any of the five snapshots.** No npm install-lifecycle hooks exist in any
repo. No dynamic evaluation of untrusted strings. No credential file is read and
transmitted.

Notable positives (defensive engineering):

- **token-optimizer `install.sh`** verifies files against **out-of-band checksums
  fetched from the GitHub Release** (not the repo tree), pins to release tags, and
  rolls back unverified updates. `curl` targets are limited to `api.github.com`
  and the release asset URL.
- **token-optimizer `python-launcher.sh`** enforces an anti-PATH-hijack allowlist,
  rejects `..` traversal, and requires owned (umask 077) cache dirs — refusing
  world-writable fallbacks.
- **token-optimizer** ships `credential_patterns.py` / `context_intel.py` that
  *detect and preserve* secrets during compression and *deny* reading `.env` /
  `.ssh`. `measure.py` only checks *presence* of `ANTHROPIC_API_KEY` (non-empty)
  to infer billing mode; it never reads or sends the value.
- **codegraph** keeps a sensitive-dir skip list (`.ssh`, `.aws`, `.gnupg`) so
  indexing avoids those paths.
- **caveman/skills** `block-dangerous-git.sh` is a *safety* hook that blocks
  destructive git commands.

### Items to be aware of (not malicious — user's call)

1. **CodeGraph telemetry is default-ON.** Anonymous only: random machine UUID
   (derived from nothing), OS/arch, tool/CLI versions, command names, and indexed
   language names. Verified against the wire payload — it sends **no code, no file
   paths, no file names, no repo identity**. Endpoint:
   `https://telemetry.getcodegraph.com/v1/events`. It also does a **daily GitHub
   update check** (version number only) and offers an **opt-in email waitlist**.
   Fail-silent; honors opt-out. *Mitigation applied below.*

2. **`curl … | sh` install lines** appear in codegraph docs (README/quickstart).
   Convenience, not covert — but prefer cloning your pinned fork and running the
   installer locally. *Mitigation: pinning + local install below.*

3. **Maintainer dev note** in `ube_codegraph/CLAUDE.md` line 193:
   `ssh colby@10.211.55.3 "powershell ..."` — a private RFC1918 address; harmless
   to you. *Mitigation: deleted below.*

4. **LLM API endpoints** (`api.openai.com`, `openrouter.ai`, `api.minimax.io`,
   Gemini) appear in codegraph / code-review-graph for the embedding features.
   They fire only when you supply your own API key.

### Non-findings (checked, cleared)

- "Binary file matches" on `codegraph/src/telemetry/index.ts` = em-dash (`—`)
  characters in comments plus one `\x00` used as a string-join delimiter. Not an
  obfuscated payload.
- All `eval(`/`exec(` grep hits = JavaScript `regex.exec()` and Python
  `re.compile()`, not code execution.
- `telemetry-worker` `POSTHOG_KEY` = the server-side ingest worker's own key, not
  read from your machine.
- caveman wizard `ask_secret STRIPE_SECRET_KEY` = a scaffolding template that
  writes *your* key to *your own* local `.env`; no transmission.

## Limitations

- Point-in-time static review of the uploaded snapshots only.
- Test suites were **not** run (no network to dependencies in the review sandbox).
- Fork-vs-upstream commit equivalence was **not** verified; capture and diff SHAs
  yourself.
- Absence of a backdoor cannot be proven; this raises confidence, not certainty —
  especially for tools that legitimately run hooks and inject agent instructions.

## Hardening applied

- [ ] **Pin** each fork to the reviewed commit; do not track `main`. Record SHAs
  in the table above.
- [ ] **Telemetry off** via shell env (`CODEGRAPH_TELEMETRY=0`, `DO_NOT_TRACK=1`)
  — see `harden-token-stack.env`. Optionally also run `codegraph telemetry off`.
- [ ] **Remove** the `ssh colby@...` line from `ube_codegraph/CLAUDE.md:193`.
- [ ] **Trial** in a throwaway repo with **no live cloud credentials** in the
  environment before enabling on real projects.
- [ ] Prefer local `bash install.sh` (checksum-verified for token-optimizer) over
  `curl | sh`.

## Re-audit triggers

Re-review when any fork is updated from upstream, before syncing the code index
for a large task, and whenever a new hook or skill is added.
