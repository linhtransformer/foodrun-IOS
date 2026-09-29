import { test, expect } from '@playwright/test';

test.describe('NFC clock-in', () => {
  test('the NFC overlay screen is defined in the DOM', async ({ page }) => {
    await page.goto('/index.html');
    // Existence check — the overlay may or may not be visible depending on state.
    await expect(page.locator('[data-screen-label="NFC clock-in"]')).toHaveCount(1);
  });

  test('shifts hero shows the listening strip', async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts).toContainText(/Hold your phone|tag on Truck/i);
  });

  test('tag-detected flash reachable via listening strip', async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    const strip = page.getByText(/Hold your phone/i).first();
    await strip.click({ trial: false }).catch(() => {});
    // The mirror auto-fires in ~2.8s; give it a beat and check that the NFC overlay
    // eventually toggles visible OR that a result sheet copy appears.
    await page.waitForTimeout(3200);
    const seen = await page.getByText(/You're clocked in|Shift complete|Tag detected/i).count();
    expect(seen).toBeGreaterThan(0);
  });
});
