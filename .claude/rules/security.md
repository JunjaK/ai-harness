---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,cjs,vue,svelte,kt,java,py,go,rb,php,cs,sql}"
---

# Security

Loads when source files are read. (The Phase 5 audit is mandatory for every team workflow regardless — kept always-on in `CLAUDE.md`.)

- MUST NOT commit secrets (keys, tokens, passwords) — use env vars via the config module.
- MUST NOT use `eval`, `new Function`, or `innerHTML` with unsanitized input.
- MUST sanitize user input before rendering or DB insert; MUST parameterize every SQL query.
- Phase 5 security audit is MANDATORY for every team workflow (`security-review` skill — OWASP Top 10 + audit format).
