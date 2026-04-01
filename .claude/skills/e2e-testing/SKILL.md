---
name: e2e-testing
description: "Playwright E2E testing patterns. Use in Phase 4 (Verification) by Tester agents. Covers Page Object Model, test structure, configuration, flaky test strategies, artifact management, and CI/CD integration."
---

# E2E Testing Patterns

Playwright patterns for stable, fast, maintainable E2E tests.

## Test File Organization

```
tests/
├── e2e/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   └── register.spec.ts
│   ├── features/
│   │   ├── crud.spec.ts
│   │   └── search.spec.ts
│   └── api/
│       └── endpoints.spec.ts
├── fixtures/
│   ├── auth.ts
│   └── data.ts
├── pages/           # Page Object Models
│   ├── login.page.ts
│   └── dashboard.page.ts
└── playwright.config.ts
```

## Page Object Model

```typescript
import { Page, Locator } from '@playwright/test';

export class ItemsPage {
  readonly page: Page;
  readonly searchInput: Locator;
  readonly itemCards: Locator;
  readonly createButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.searchInput = page.locator('[data-testid="search-input"]');
    this.itemCards = page.locator('[data-testid="item-card"]');
    this.createButton = page.locator('[data-testid="create-btn"]');
  }

  async goto() {
    await this.page.goto('/items');
    await this.page.waitForLoadState('networkidle');
  }

  async search(query: string) {
    await this.searchInput.fill(query);
    await this.page.waitForResponse(r => r.url().includes('/api/search'));
  }
}
```

## Test Structure

```typescript
import { test, expect } from '@playwright/test';
import { ItemsPage } from '../pages/items.page';

test.describe('Item Search', () => {
  let itemsPage: ItemsPage;

  test.beforeEach(async ({ page }) => {
    itemsPage = new ItemsPage(page);
    await itemsPage.goto();
  });

  test('should search by keyword', async () => {
    await itemsPage.search('test');
    await expect(itemsPage.itemCards.first()).toContainText(/test/i);
  });

  test('should handle no results', async ({ page }) => {
    await itemsPage.search('xyznonexistent');
    await expect(page.locator('[data-testid="no-results"]')).toBeVisible();
  });
});
```

## Selector Priority

1. `getByRole()` — Accessibility roles
2. `getByLabel()` — Form labels
3. `getByPlaceholder()` — Input placeholders
4. `getByText()` — Visible text
5. `getByTestId()` — `data-testid` (last resort)

## Flaky Test Fixes

| Cause | Bad | Good |
|-------|-----|------|
| Race condition | `page.click(selector)` | `page.locator(selector).click()` |
| Network timing | `page.waitForTimeout(5000)` | `page.waitForResponse(...)` |
| Animation | Click during animation | `waitFor({ state: 'visible' })` |

## Wait Patterns

```typescript
// Wait for API response
const responsePromise = page.waitForResponse(
  r => r.url().includes('/api/data') && r.status() === 200
);
await page.locator('[data-testid="submit"]').click();
await responsePromise;

// Wait for element state
await page.locator('[data-testid="modal"]').waitFor({ state: 'visible' });
```

## Artifact Management

```typescript
// Screenshots
await page.screenshot({ path: 'artifacts/result.png' });
await page.screenshot({ path: 'artifacts/full.png', fullPage: true });

// Element screenshot
await page.locator('[data-testid="chart"]').screenshot({
  path: 'artifacts/chart.png'
});
```

## Configuration

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['html'], ['json', { outputFile: 'results.json' }]],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],
});
```
