-- SorryCensus.lean: fixture corpus for lean-sorry-census.sh (task 783)
-- Each case below is labeled. Genuine code sorries are marked GENUINE and must be the
-- only lines reported by the census. All other cases MUST NOT be counted.

-- Case 1: full-line `--` comment containing the word sorry (MUST NOT count)
-- sorry

-- Case 2: genuine sorry in a theorem body (MUST count) -- GENUINE #1
theorem case2_genuine : True := by
  sorry

-- Case 3: trailing inline `--` comment sorry on an otherwise sorry-free code line
theorem case3_trailing : True := trivial  -- no longer uses sorry

-- Case 4: single-line `/-- ... -/` docstring containing sorry twice (MUST NOT count)
/-- This proof is sorry-free after removing the sorry. -/
theorem case4_docstring : True := trivial

-- Case 5: multi-line docstring sorry -- exact task-431 bug pattern (MUST NOT count)
/--
This lemma is now sorry-free after removing the sorry from the earlier draft.
-/
theorem case5_multiline_doc : True := trivial

-- Case 6: nested `/- -/` block comment sorry (MUST NOT count; proves nesting-depth tracking)
/- outer /- inner sorry -/ still outer -/
theorem case6_nested : True := trivial

-- Case 7: commented-out TODO stub -- literal task-431 case (MUST NOT count)
/-
TODO: this used to be `theorem foo := by sorry`, revisit later.
-/
theorem case7_stub : True := trivial

-- Case 8: string-literal edge case; the string body must not be parsed as a comment opener
#eval "not a -- comment, not /- either, sorry"

-- Case 9: second genuine sorry at end of file (MUST count) -- GENUINE #2
theorem case9_genuine : True := by
  sorry
