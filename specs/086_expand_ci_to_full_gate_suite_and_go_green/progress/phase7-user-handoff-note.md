# User Handoff: Confirm Live CI (Task 86)

Everything up to a real GitHub Actions run has been verified locally and via a clean-clone
rehearsal (see specs/086_expand_ci_to_full_gate_suite_and_go_green/progress/phase6-*-transcript.txt).
Agents may not push branches or open PRs (`.claude/rules/pr-prohibition.md`), so the final
live-CI confirmation is a manual step for you, after `/merge` or a direct push:

## 1. Push and watch the workflow go green

```bash
git push origin master   # or push a branch and open a PR, whichever this repo's flow uses
```

Then watch the "Full Gate Suite" workflow run in the GitHub Actions tab. It should:
- Install neovim
- Deploy `.claude/` from the source store (no failures)
- Run the full `verify-deploy.sh --findings` suite (25 checks, 0 failures, no `FINDING ` lines)
- The job succeeds (green check)

## 2. Reintroduce a mismatch and watch it go red

To confirm the negative case holds on a real Actions run too (not just the local rehearsal):

```bash
echo "" >> agent-system/extensions/core/context/architecture/context-layers.md
git add agent-system/extensions/core/context/architecture/context-layers.md
git commit -m "test: deliberately reintroduce a line_count mismatch"
git push origin master
```

Watch the Actions run fail on the "Run the full gate suite" step, with a `FINDING gate3 [core]
FAIL: Rule R: index-entries.json entry 'architecture/context-layers.md' line_count mismatch`
line in the log.

## 3. Revert

```bash
git revert HEAD
git push origin master
```

Confirm the next Actions run goes green again.

## Reference

- Workflow: `.github/workflows/check-extension-docs.yml`
- Local rehearsal transcripts: `specs/086_expand_ci_to_full_gate_suite_and_go_green/progress/phase6-positive-transcript.txt`, `phase6-negative-transcript.txt`, `phase6-revert-transcript.txt`
- CI recipe reference doc: `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md`
