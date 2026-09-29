import { test, expect } from '@playwright/test';

test.describe('tasks / checklist', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    // Tab bar → Tasks. (Depending on state, may open the gated preview first;
    // spec still passes because the screen exists.)
    await page.getByText('Tasks', { exact: true }).first().click();
  });

  test('checklist header + progress card render', async ({ page }) => {
    const tasks = page.locator('[data-screen-label="Tasks"]');
    await expect(tasks).toBeVisible();
    await expect(tasks).toContainText('Shift checklist');
    await expect(tasks).toContainText(/COMPLETED/);
    await expect(tasks).toContainText(/\d\s*\/\s*7/);
  });

  test('all 7 checklist items visible', async ({ page }) => {
    const tasks = page.locator('[data-screen-label="Tasks"]');
    // Real content per bundle §4.
    for (const item of [
      /prep station/i, /gas bottles/i, /opening stock/i,
      /fridge temperature/i, /POS/i, /closing waste/i, /truck.?clean/i,
    ]) {
      await expect(tasks).toContainText(item);
    }
  });

  test('submit checklist CTA present', async ({ page }) => {
    const tasks = page.locator('[data-screen-label="Tasks"]');
    await expect(tasks.getByText(/Submit checklist/i)).toBeVisible();
  });
});
