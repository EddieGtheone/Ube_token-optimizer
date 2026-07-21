#!/usr/bin/env bash
# apply-hardening.sh — apply the mechanical hardening steps from SECURITY-AUDIT.md.
# Run from the directory that contains your cloned ube_ forks, e.g.:
#   ~/src/ube_token-optimizer  ~/src/ube_codegraph  ...
# Review before running. Safe to re-run (idempotent).
set -euo pipefail

# 1) Strip the maintainer dev-note ssh line from codegraph's CLAUDE.md.
CG_CLAUDE="ube_codegraph/CLAUDE.md"
[ -f "$CG_CLAUDE" ] || CG_CLAUDE="ube_codegraph-main/CLAUDE.md"
if [ -f "$CG_CLAUDE" ] && grep -q 'ssh colby@10\.211\.55\.3' "$CG_CLAUDE"; then
  cp "$CG_CLAUDE" "${CG_CLAUDE}.bak"
  # Delete the single offending line; keep everything else.
  grep -v 'ssh colby@10\.211\.55\.3' "$CG_CLAUDE" > "${CG_CLAUDE}.tmp" && mv "${CG_CLAUDE}.tmp" "$CG_CLAUDE"
  echo "> Removed ssh dev-note line from $CG_CLAUDE (backup: ${CG_CLAUDE}.bak)"
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
