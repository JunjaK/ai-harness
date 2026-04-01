---
name: api-design
description: "REST API design patterns. Use in Phase 1 (Planning) by Architect B for API contract design. Covers resource naming, status codes, pagination, filtering, error responses, versioning, and rate limiting."
---

# API Design Patterns

## Resource Design

```
GET    /api/v1/users          # List
POST   /api/v1/users          # Create
GET    /api/v1/users/:id      # Read
PUT    /api/v1/users/:id      # Update (full)
PATCH  /api/v1/users/:id      # Update (partial)
DELETE /api/v1/users/:id      # Delete
```

**Naming rules:**
- Plural nouns: `/users`, `/orders`
- Kebab-case: `/team-members`
- Nest for relationships: `/users/:id/orders`
- Actions as verbs (sparingly): `/orders/:id/cancel`

## Status Codes

| Code | Meaning | Use |
|------|---------|-----|
| 200 | OK | Successful GET/PUT/PATCH |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Validation error |
| 401 | Unauthorized | Missing/invalid auth |
| 403 | Forbidden | Authenticated but not allowed |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate or state conflict |
| 422 | Unprocessable | Valid syntax, invalid semantics |
| 429 | Too Many Requests | Rate limited |
| 500 | Server Error | Unexpected failure |

## Response Format

### Success (single)
```json
{
  "data": { "id": "123", "name": "Test" }
}
```

### Success (collection)
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

### Error
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ]
  }
}
```

## Pagination

### Offset-based (simple, dashboards)
```
GET /api/v1/users?page=2&per_page=20
```

### Cursor-based (feeds, large datasets)
```
GET /api/v1/posts?cursor=abc123&limit=20
```

## Filtering & Sorting

```
GET /api/v1/users?status=active&role=admin
GET /api/v1/users?sort=-created_at,name
GET /api/v1/users?created_at[gte]=2024-01-01
GET /api/v1/users?search=john
```

## Versioning

- URL path versioning: `/api/v1/`, `/api/v2/`
- Max 2 active versions
- Non-breaking changes don't need new version

### Non-breaking (safe)
- Adding new fields to response
- Adding new optional query parameters
- Adding new endpoints

### Breaking (new version)
- Removing or renaming fields
- Changing field types
- Changing endpoint URLs

## Rate Limiting Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1609459200
Retry-After: 60
```

## Pre-Ship Checklist

- [ ] URLs use plural nouns, kebab-case
- [ ] Correct HTTP methods for CRUD
- [ ] Proper status codes (not 200 for errors)
- [ ] Input validation with clear errors
- [ ] Consistent error response format
- [ ] Pagination for list endpoints
- [ ] Auth on protected endpoints
- [ ] Rate limiting configured
- [ ] API versioning in URL
