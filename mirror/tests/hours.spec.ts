import { test, expect } from '@playwright/test';

test.describe('hours', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    await page.getByText('Hours', { exact: true }).first().click();
    await expect(page.locator('[data-screen-label="Hours"]')).toBeVisible();
  });

  test('period kicker + title + Approved chip', async ({ page }) => {
    const hours = page.locator('[data-screen-label="Hours"]');
    await expect(hours).toContainText(/PERIOD \d/);
    await expect(hours).toContainText('Your hours');
    await expect(hours).toContainText(/Approved/);
  });

  test('two KPI cards: Approved + Pending', async ({ page }) => {
    const hours = page.locator('[data-screen-label="Hours"]');
    await expect(hours).toContainText('Approved');
    await expect(hours).toContainText('Pending');
    // Dutch decimal comma required per bundle §Typography.
    await expect(hours).toContainText(/\d+,\d\s*h/);
  });

  test('Waiting-for-you tile with submit CTA', async ({ page }) => {
    const hours = page.locator('[data-screen-label="Hours"]');
    await expect(hours).toContainText(/Waiting for you|Submit \d/i);
  });

  test('approved-hours screen reachable from chip', async ({ page }) => {
    await page.locator('[data-screen-label="Hours"]').getByText(/Approved/).first().click();
    await expect(page.locator('[data-screen-label="Approved hours"]')).toBeVisible();
  });
});
