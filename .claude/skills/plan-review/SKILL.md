---
name: plan-review
description: "Critical plan review for evaluating implementation plans, feature proposals, and architectural decisions. Focuses on worst-case analysis, risks, performance bottlenecks, UI/UX concerns, and edge cases. Use during Phase 1 cross-review or before any code is written."
---

# Plan Review

Critical review of implementation plans — before code is written.

## Core Philosophy

**Think like a pessimist, review like an adversary.**
Assume everything that can go wrong will go wrong. Surface hidden risks, not validate the plan.

## Review Process

### Phase 1: Context Gathering

1. Read the plan document (from `_docs/` or user-provided)
2. Identify affected areas in the codebase
3. Read related existing code — stores, services, API types involved
4. Check database schema if data relations are involved

### Phase 2: Risk Analysis

Evaluate each area. Skip sections that don't apply, but state "N/A" with reason.

#### Data Integrity & Race Conditions
- Concurrent edits: two users modifying same data simultaneously?
- Partial failure: API call succeeds halfway (3 of 5 rows saved)?
- Stale data: user acts on data that changed since page load?
- Cascade effects: modifying A silently breaks B?
- Undo/rollback: if something goes wrong, can the user recover?

#### Performance & Scalability
- Data volume: what happens with 10x, 100x current data?
- API call count: N+1 queries? Redundant fetches?
- Reactivity chains: deep watch chains triggering cascading re-renders?
- Memory leaks: event listeners, intervals not cleaned up?
- Bundle size: large imports that could be lazy-loaded?

#### UI/UX Pitfalls
- Loading states: what does user see during slow API calls?
- Error states: what happens when API fails?
- Optimistic updates: UI updates before server confirms?
- Accessibility: keyboard navigation, focus management?
- User confusion: are action consequences clear?
- Feedback timing: success/error messages appear promptly?

#### Edge Cases & Boundary Conditions
- Empty states (no data, no permissions)
- Maximum limits (max rows, max file size)
- Special characters in input (quotes, unicode, HTML tags)
- Locale differences (text length breaking layout)
- Browser back/forward during operations
- Token expiry during long operations
- Network disconnect mid-save

#### Security Concerns
- User input sanitization (XSS vectors)
- Permission checks: unauthorized access via URL manipulation?
- Sensitive data in API responses or browser storage
- CSRF protection on state-changing operations

#### Maintenance & Complexity
- Tight coupling between modules?
- Will future developers understand the flow?
- Simpler alternatives that achieve the same goal?
- Duplicate logic that already exists?
- How many files change? (More files = higher merge conflict risk)

### Phase 3: Verdict

```markdown
## Plan Review: [Plan Name]

### Summary
[1-2 sentence overview]

### Risk Level: [LOW | MEDIUM | HIGH | CRITICAL]

### Findings

#### [CRITICAL] Title
- **Risk**: What can go wrong
- **Impact**: How bad (data loss? UX degradation? performance cliff?)
- **Recommendation**: Specific fix or mitigation

#### [HIGH] Title
...

### Performance Assessment
- Current expected load: ...
- Breaking point estimate: ...
- Bottleneck: ...

### UI/UX Assessment
- User flow clarity: ...
- Error handling completeness: ...
- Missing states: ...

### Missing from Plan
- [ ] Items that should be in the plan but aren't

### Verdict
[APPROVE | APPROVE WITH CONDITIONS | REQUEST REVISION | REJECT]
```

## Severity Definitions

| Level | Meaning | Action |
|-------|---------|--------|
| CRITICAL | Data loss, security vulnerability, system-breaking | Must fix before implementation |
| HIGH | Significant UX degradation or performance cliff | Should fix before implementation |
| MEDIUM | Suboptimal but functional, tech debt risk | Fix during or as follow-up |
| LOW | Nice-to-have, minor concern | Optional |

## Anti-Patterns

- **Don't** just say "looks good" — always find at least one concern
- **Don't** nitpick formatting when architecture is at stake
- **Don't** raise theoretical risks without realistic trigger scenarios
- **Do** provide concrete examples of how each risk manifests
- **Do** suggest specific mitigations, not just "be careful about X"
