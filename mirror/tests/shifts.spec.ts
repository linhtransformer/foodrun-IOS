import { test, expect } from '@playwright/test';

// Shifts screen — the home. Mode pills, week carousel, hero card, selected day.

test.describe('shifts', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    await expect(page.locator('[data-screen-label="Shifts"]')).toBeVisible();
  });

  test('header shows kicker + greeting + avatar', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts).toContainText(/WEDNESDAY \d{1,2} SEP/);
    await expect(shifts).toContainText('Hey Sanne');
    await expect(shifts.getByText('SV')).toBeVisible();
  });

  test('hero opens collapsed and toggles to expanded', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    // Collapsed: 26pt clock — small heading with "19:00" but no 52pt expanded form.
    await expect(shifts).toContainText('19:00');
    await expect(shifts).toContainText('NEXT SHIFT');
    await expect(shifts).toContainText('Truck Mees');
    // Toggle pill — the minus/plus pill at top-center of hero.
    const heroToggle = shifts.locator('[style*="top:12px"][style*="left:50%"]').first();
    await heroToggle.click();
    // After expand, the location line should appear.
    await expect(shifts).toContainText('Kitchen');
  });

  test('mode pills present and switchable', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    await expect(shifts.getByText('Shifts', { exact: true }).first()).toBeVisible();
    await expect(shifts.getByText('Roster', { exact: true })).toBeVisible();
    await expect(shifts.getByText('Availability', { exact: true })).toBeVisible();
    // Switch to Roster — expect "N people on shift" language.
    await shifts.getByText('Roster', { exact: true }).click();
    await expect(shifts).toContainText(/\d people on shift|Nobody rostered/);
    // Switch to Availability — expect the range readout format.
    await shifts.getByText('Availability', { exact: true }).click();
    await expect(shifts).toContainText(/\d{2}:\d{2}\s*[–-]\s*\d{2}:\d{2}/);
  });

  test('week carousel hidden on Shifts pill, shown on Roster + Availability', async ({ page }) => {
    const shifts = page.locator('[data-screen-label="Shifts"]');
    // Shifts pill (default): no "Week NN" label.
    await expect(shifts).not.toContainText(/Week \d{1,2}/);
    // Roster: carousel appears.
    await shifts.getByText('Roster', { exact: true }).click();
    await expect(shifts).toContainText(/Week \d{1,2}/);
    // Availability: carousel stays.
    await shifts.getByText('Availability', { exact: true }).click();
    await expect(shifts).toContainText(/Week \d{1,2}/);
  });
});
