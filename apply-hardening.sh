#!/usr/bin/env bash
# apply-hardening.sh — apply the mechanical hardening steps from SECURITY-AUDIT.md.
# Run from the directory that contains your cloned ube_ forks, e.g.:
#   ~/src/ube_token-optimizer  ~/src/ube_codegraph  ...
# Review before running. Safe to re-run (idempotent).
set -euo pipefail

# 1) Strip the maintainer dev-note ssh example from codegraph's CLAUDE.md.
#    The ssh line lives inside a fenced ``` code block; remove the WHOLE block
#    (fences included) so no orphaned fragment is left behind.
CG_CLAUDE="ube_codegraph/CLAUDE.md"
[ -f "$CG_CLAUDE" ] || CG_CLAUDE="ube_codegraph-main/CLAUDE.md"
if [ -f "$CG_CLAUDE" ] && grep -q 'ssh colby@10\.211\.55\.3' "$CG_CLAUDE"; then
  cp "$CG_CLAUDE" "${CG_CLAUDE}.bak"
  # Buffer each fenced block; drop only the block that contains the ssh line,
  # emit every other line (and every other code block) verbatim.
  awk '
    function flush() {
      if (!has_ssh) printf "%s", block
      block = ""; has_ssh = 0
    }
    {
      trimmed = $0; sub(/^[ \t]+/, "", trimmed)
      is_fence = (trimmed ~ /^```/)
      if (!in_block) {
        if (is_fence) { in_block = 1; block = $0 ORS }
        else print
      } else {
        block = block $0 ORS
        if ($0 ~ /ssh colby@10\.211\.55\.3/) has_ssh = 1
        if (is_fence) { in_block = 0; flush() }
      }
    }
    END { if (in_block) printf "%s", block }  # unterminated block: keep as-is
  ' "$CG_CLAUDE" > "${CG_CLAUDE}.tmp" && mv "${CG_CLAUDE}.tmp" "$CG_CLAUDE"
  echo "> Removed ssh dev-note code block from $CG_CLAUDE (backup: ${CG_CLAUDE}.bak)"
else
  echo "! $CG_CLAUDE not found or line already gone — skipping"
fi

# 2) Pin each fork to its current HEAD (detached) so it stops tracking main.
#    Record the SHA into SECURITY-AUDIT.md's table manually.
for repo in ube_token-optimizer ube_codegraph ube_code-review-graph ube_caveman ube_skills; do
  if [ -d "$repo/.git" ]; then
    sha="$(git -C "$repo" rev-parse HEAD)"
    echo "> $repo pinned at $sha"
    echo "    (to lock: git -C $repo checkout $sha)"
  else
    echo "! $repo is not a git checkout — pin after cloning your fork"
  fi
done

echo
echo "Next:"
echo "  - source harden-token-stack.env  (telemetry off)"
echo "  - fill the reviewed SHAs into SECURITY-AUDIT.md"
echo "  - trial in a throwaway repo with no live cloud creds"
