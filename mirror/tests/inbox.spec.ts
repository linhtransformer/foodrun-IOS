import { test, expect } from '@playwright/test';

test.describe('inbox', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    await page.getByText('Inbox', { exact: true }).first().click();
    await expect(page.locator('[data-screen-label="Inbox"]')).toBeVisible();
  });

  test('unread kicker + title', async ({ page }) => {
    const inbox = page.locator('[data-screen-label="Inbox"]');
    await expect(inbox).toContainText(/\d UNREAD/);
    await expect(inbox).toContainText('Inbox');
  });

  test('at least one row with an agent (black rounded square)', async ({ page }) => {
    const inbox = page.locator('[data-screen-label="Inbox"]');
    // The Foodrun agent avatar is a black rounded square with a white "F".
    // Match by visible "F" and the surrounding row.
    await expect(inbox.getByText('F', { exact: true }).first()).toBeVisible();
  });
});
