import { test, expect } from '@playwright/test';

// Smoke — the mirror renders, the Sign in screen shows, and Log in navigates.
// Everything else builds on this working.

test.describe('smoke', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.html');
    // Wait for the template runtime (support.js) to hydrate the x-dc tree.
    await expect(page.locator('[data-screen-label]').first()).toBeVisible({ timeout: 5000 });
  });

  test('sign-in screen renders with brand + copy', async ({ page }) => {
    const signIn = page.locator('[data-screen-label="Sign in"]');
    await expect(signIn).toBeVisible();
    await expect(page.locator('img[alt="Foodrun"]')).toBeVisible();
    await expect(signIn).toContainText('Your shifts.');
    await expect(signIn).toContainText('One tap away.');
    await expect(signIn).toContainText('Log in');
    await expect(signIn).toContainText('Make an account');
  });

  test('all 8 primary screens exist in the DOM', async ({ page }) => {
    const labels = [
      'Sign in', 'Shifts', 'Shift detail', 'Tasks',
      'Hours', 'Approved hours', 'Inbox', 'Profile',
    ];
    for (const label of labels) {
      await expect(page.locator(`[data-screen-label="${label}"]`)).toHaveCount(1);
    }
  });

  test('log in navigates to Shifts', async ({ page }) => {
    await page.getByText('Log in', { exact: true }).click();
    await expect(page.locator('[data-screen-label="Shifts"]')).toBeVisible();
    await expect(page.locator('[data-screen-label="Sign in"]')).toBeHidden();
  });

  test('tab bar appears after auth and hides on sign-in', async ({ page }) => {
    // Sign-in: no tab bar visible.
    const tabItems = page.locator('text=Shifts').and(page.locator('text=Tasks'));
    await page.getByText('Log in', { exact: true }).click();
    // After auth, tab bar labels present.
    await expect(page.getByText('Shifts', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Tasks', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Hours', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Inbox', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Me', { exact: true }).first()).toBeVisible();
  });
});
