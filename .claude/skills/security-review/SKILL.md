---
name: security-review
description: "Security vulnerability detection and remediation. Use in Phase 5 (Final Review) by Architect C, when handling user input, authentication, API endpoints, or sensitive data. Covers OWASP Top 10, secrets management, and pre-deployment checklist."
---

# Security Review

## When to Activate

- Implementing authentication or authorization
- Handling user input or file uploads
- Creating new API endpoints
- Working with secrets or credentials
- Implementing payment features
- Storing or transmitting sensitive data

## Security Areas

### 1. Secrets Management
- Environment variables required; hardcoded credentials BANNED
- `.env` files in `.gitignore`
- No secrets in client-side code or logs

### 2. Input Validation
- Validate all user input (type, length, format)
- Use schema validation (Zod, Joi, etc.)
- File uploads: validate size, type, extension

### 3. SQL/NoSQL Injection
- Parameterized queries only
- No string concatenation in queries
- ORM/query builder preferred

### 4. Authentication & Authorization
- HttpOnly cookies for session tokens
- Authorization checks on every protected endpoint
- Verify resource ownership (not just authentication)

### 5. XSS Prevention
- Sanitize HTML output (DOMPurify or framework escaping)
- Content Security Policy headers
- No `innerHTML` with user-provided content

### 6. CSRF Protection
- CSRF tokens on state-changing operations
- SameSite cookie attribute (Strict or Lax)

### 7. Rate Limiting
- Apply to all public endpoints
- Stricter limits on auth endpoints (login, register)
- Return 429 with Retry-After header

### 8. Sensitive Data Exposure
- Redact sensitive data in logs
- Generic error messages to users (no stack traces)
- HTTPS only in production

### 9. Dependency Security
- Regular `npm audit` / `pnpm audit`
- Lock files committed
- Review new dependencies before adding

## Pre-Deployment Checklist

- [ ] No hardcoded secrets in code
- [ ] No `console.log` with sensitive data
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (output encoding, CSP)
- [ ] CSRF tokens on state-changing requests
- [ ] Authentication on protected routes
- [ ] Authorization checks (resource ownership)
- [ ] Rate limiting on public endpoints
- [ ] HTTPS enforced
- [ ] Security headers set (CSP, HSTS, X-Frame-Options)
- [ ] Error messages don't leak internals
- [ ] Logging doesn't include sensitive data
- [ ] Dependencies audited (`npm audit`)
- [ ] File upload validation (size, type)
- [ ] Session management secure (HttpOnly, Secure, SameSite)
- [ ] CORS configured properly
