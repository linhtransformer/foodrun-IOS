import { test, expect } from '@playwright/test';

test.describe('availability mode', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    await page.getByText('Availability', { exact: true }).click();
  });

  test('stepper rows for wanted + standard shifts', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts).toContainText('Shifts you want this week');
    await expect(shifts).toContainText('Standard shifts per week');
  });

  test('dual-handle slider present with 00:00 / 12:00 / 24:00 scale', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts).toContainText('00:00');
    await expect(shifts).toContainText('12:00');
    await expect(shifts).toContainText('24:00');
    // Two range inputs = dual handle.
    const ranges = shifts.locator('input.fr-range');
    await expect(ranges).toHaveCount(2);
  });

  test('state buttons (Available / Not available) both render', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts.getByText('Not available', { exact: true })).toBeVisible();
    await expect(shifts.getByText('Available', { exact: true })).toBeVisible();
  });

  test('closes-Thu amber pill + agent note present', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts).toContainText(/CLOSES/i);
    await expect(shifts).toContainText(/agent will schedule|open windows/i);
  });
});
