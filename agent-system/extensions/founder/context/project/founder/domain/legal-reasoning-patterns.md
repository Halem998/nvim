# Legal Reasoning Patterns

Domain knowledge for the legal-analysis-agent: how attorneys think, reason, and evaluate -- structured as translation knowledge for helping users describe legal AI products in language attorneys recognize.

## Attorney Reasoning Patterns

### 1. IRAC: Issue, Rule, Application, Conclusion

Attorneys organize analysis using IRAC: identify the legal issue, state the applicable rule, apply the rule to the facts, and reach a conclusion. This is not a discovery process -- it is a structured argumentation framework.

**Design implication**: When a product claims to "analyze" or "reason," attorneys expect to see the IRAC structure. A tool that "finds conclusions" without showing issue identification, rule selection, and application will seem opaque. Describe what the tool contributes to each IRAC step rather than claiming it performs the whole sequence.

### 2. Reasoning by Example and Analogy

Attorneys reason from case to case. They classify new situations by comparing them to prior cases and extracting principles through analogy, not by deriving conclusions from axioms.

**Design implication**: Products that claim to "reason from first principles" or "prove conclusions" use language that does not map to how attorneys build arguments. Reframe as: "Logos identifies relevant precedent patterns and maps case facts to established analytical frameworks." Ask: "When you say the system 'proves' X, what is the analogous process in legal practice?"

### 3. Evidence Evaluation, Not Verification

Attorneys assess evidence by weighing credibility, relevance, and sufficiency against a burden of proof (preponderance, clear and convincing, beyond reasonable doubt). They do not "verify" evidence in a mathematical or computational sense.

**Design implication**: "Formally verified" is meaningful in computer science but maps to no recognized legal standard. Reframe as: "auditable reasoning chain" or "transparent logical steps that can be inspected." Ask: "How does the system's verification relate to an attorney's process of evaluating whether evidence meets a legal standard?"

### 4. Discretionary Judgment

Legal reasoning involves open-textured terms ("reasonable," "material," "good faith") that require contextual judgment. The probabilistic nature of AI conflicts with law's principled, choice-driven nature. Attorneys exercise professional judgment -- they do not execute algorithms.

**Design implication**: Product descriptions must make clear where the tool defers to attorney judgment and where it provides analytical support. Claiming the tool "determines" or "concludes" in areas requiring professional discretion will generate resistance. Ask: "Where in this description are you claiming the system makes judgments that attorneys would expect to make themselves?"

### 5. Argument Construction Through Professional Judgment

Arguments are constructed, not discovered. Building a theory of the case -- selecting which facts to emphasize, which legal theories to pursue, how to frame the narrative -- is the core of attorney professional identity. Products that claim to "find" arguments or "discover" conclusions imply the tool does work attorneys consider uniquely theirs.

**Design implication**: Reframe from "Logos finds the argument" to "Logos provides the evidential foundation and reasoning infrastructure that supports constructing..." The distinction between finding (passive) and constructing (active, professional) is fundamental to how attorneys understand their role.

## Translation Gap Categories

Five categories of divergence between technical product descriptions and attorney interpretation. These are not errors -- they represent places where genuine capabilities are described using the wrong professional vocabulary.

### 1. Terminology Mismatch

Technical terms that have different meanings in legal practice.

**Detection heuristics**:
- Legal terms of art used outside their formal context (e.g., "discovery" meaning analysis rather than FRCP 26-37 pretrial process)
- Computer science terms with no legal equivalent (e.g., "formally verified," "proof")
- Borrowed legal concepts used as metaphors rather than with precise legal meaning

**Examples**:
| Technical Language | Attorney Reading | Suggested Reframing |
|---|---|---|
| "discovery" (as analysis) | Formal pretrial process governed by rules | "analysis," "investigation," or "examination" |
| "formally verified" | No legal equivalent; triggers "prove what?" | "auditable reasoning chain," "transparent logical steps" |
| "proof, not an opinion" | Opposing counsel has no obligation to accept any proof | "documented reasoning grounded in specific evidence" |

### 2. Process and Timeline Confusion

Describing product workflows using terms that map to formal legal procedures with specific timing, rules, and professional obligations.

**Detection heuristics**:
- Phase/stage descriptions that mirror formal litigation phases
- Claims about "completing" processes that are inherently ongoing in legal practice
- Workflow descriptions that imply the tool manages the legal process rather than supporting it

**Examples**:
- "Five-phase workflow" reads as if the tool does the lawyer's job rather than supporting attorney-directed work
- "Case evaluation" as a product feature vs. case evaluation as an ongoing professional judgment throughout representation

### 3. Ethical and Accuracy Claims

Product descriptions that invoke professional responsibility standards or make accuracy claims that conflict with how attorneys understand their obligations.

**Detection heuristics**:
- References to specific ethical rules (e.g., "duty of candor," Rule 3.3) used as quality benchmarks rather than professional obligations
- Claims of "completeness" in a domain attorneys know is inherently incomplete
- Accuracy claims that exceed what any tool can guarantee in legal contexts

**Examples**:
| Claim | Problem | Reframing |
|---|---|---|
| "duty of candor" as quality benchmark | Rule 3.3 is a prohibition on deception, not a work-quality standard | "supports the attorney's ability to comply with disclosure obligations" |
| "complete case representation" | Legal cases are inherently incomplete and evolving | "comprehensive case representation based on available information" |
| "ABA now requires" | May mischaracterize the scope of specific opinions | "consistent with the competence obligations [specific opinion] addresses" |

### 4. Reasoning Framework Gaps

Product descriptions that claim reasoning capabilities without mapping to how attorneys actually reason.

**Detection heuristics**:
- Claims to "reason" or "analyze" without specifying the reasoning framework
- Algorithmic language applied to judgment-dependent processes
- Claims that the tool produces "conclusions" in areas requiring professional discretion

### 5. Role Confusion

Product descriptions that blur the boundary between tool and professional, implying the product replaces attorney judgment rather than supporting it.

**Detection heuristics**:
- Active verbs that position the tool as the agent ("Logos determines," "Logos concludes," "Logos establishes")
- Workflow descriptions where the attorney is absent or passive
- Value propositions centered on speed rather than quality of attorney work product

**Examples**:
- "find the argument" implies the tool does what attorneys consider their core professional work
- "concealment established" is a legal conclusion requiring elements under specific doctrine -- the tool provides "evidence consistent with deliberate concealment"

## Common Legal AI Product Misrepresentation Patterns

Five patterns that legal AI products commonly get wrong when describing capabilities to attorneys:

1. **Claiming to replace judgment.** Attorneys value tools that help them exercise better judgment, not tools that exercise judgment for them. Frame as augmentation, not replacement.

2. **Task decomposition without professional context.** Describing legal work as a pipeline of discrete operations (retrieve, analyze, draft) misses that attorneys work holistically -- "the job itself is broader than the tasks." Show how each step supports the attorney's integrated practice.

3. **Verification language that does not map to legal standards.** "Formally verified" is meaningful in computer science but maps to no recognized legal standard. Attorneys verify by checking citations, reading underlying authority, and exercising judgment about applicability.

4. **Overstating completeness.** Claims like "complete case representation" or "all inferences" trigger skepticism from practitioners who know legal cases are inherently incomplete and evolving.

5. **Speed as primary value proposition.** "Faster is not the same as better" -- time saved generating drafts is consumed verifying them. Attorneys want accuracy, reliability, and professional defensibility, not speed.

## Vocabulary Mapping Table

| Technical Term | Attorney Interpretation | Suggested Reframing |
|---|---|---|
| formally verified | No legal equivalent; mathematically proven | auditable reasoning chain; transparent logical steps that can be inspected |
| discovery | FRCP 26-37 pretrial process with specific rules and obligations | analysis; investigation; examination |
| proof | Evidence sufficient to meet burden; opposing counsel can still challenge | documented reasoning grounded in specific evidence |
| complete representation | Impossible in practice; cases are always incomplete | comprehensive representation based on available information |
| establishes / determines | Legal conclusion with specific elements and burden | evidence consistent with; analysis suggests; supports the conclusion that |
| duty of candor | Rule 3.3 obligation not to deceive the tribunal | supports attorney compliance with disclosure obligations |
| case evaluation | Ongoing professional judgment throughout representation | analytical assessment; evidentiary analysis |
| finds the argument | Arguments are constructed by attorneys, not found by tools | surfaces evidence and reasoning supporting construction of |
| automates legal reasoning | Implies replacement of professional judgment | provides analytical infrastructure supporting attorney reasoning |
| AI-powered legal analysis | Vague; what kind of analysis? | computational analysis of [specific domain]: evidence patterns, timeline consistency, citation verification |
