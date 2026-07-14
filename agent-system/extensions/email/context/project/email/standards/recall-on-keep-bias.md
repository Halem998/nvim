# Standard: Recall-on-Keep Bias

The classifier bias standard `email-classify` (and any agent/skill reasoning about its output)
must follow.

## The Bias

Classification must bias toward **near-100% recall on `keep`**: it is far worse to lose a
message the user wanted than to leave a message the user didn't want sitting in the inbox one
extra cycle. Concretely:

- Any message where classification is not confident should resolve to `unsure` or `keep`, never
  to `archive` or `delete`.
- `keep` is the default fallback action if no rule or classifier signal confidently applies.

## Deterministic-First, LLM-on-Residual

Classification runs in tiers:

1. **Deterministic rules first** — the harvested custom rules and per-sender/domain triage rules
   (see `email-preferences.md`) are checked before any LLM judgment. These are the user's
   revealed preferences and should not be second-guessed by a model.
2. **Header-based signals next** — `List-Unsubscribe` / `Precedence: bulk` / `Auto-Submitted`
   and similar structural signals are the primary tier above keyword matching.
3. **Keyword-fallback tier** — the sender/domain/subject keyword lists in `email-preferences.md`
   are a fallback, not a primary signal.
4. **LLM judgment only on the residual** — messages that remain ambiguous after 1-3 are the only
   ones where an LLM-based judgment call is appropriate, and its output still passes through the
   confidence gate below.

## Confidence Gate for Delete

`delete` is the irreversible verb (a maildir move followed by an optional trash expunge) and
gets the strictest bar in the system:

- Auto-propose `delete` only at confidence **>= 0.90**.
- Everything below 0.90 must resolve to `unsure`, surfaced for explicit human review — never
  silently downgraded to `keep` (that would hide a legitimate cleanup candidate) and never
  auto-actioned as `delete` (that would risk destroying wanted mail).

`archive` and `keep` may use more permissive thresholds since both are reversible (a message can
always be moved back or re-surfaced), but `delete` never inherits that permissiveness.
