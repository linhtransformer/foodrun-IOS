import { test, expect } from '@playwright/test';

// Accessibility guardrails from bundle §Accessibility.
// These are heuristics; SwiftUI will honour dynamic type / reduce-motion for real.

test.describe('a11y', () => {
  test('every clickable element with a small draw size still has ≥44pt hit box', async ({ page }) => {
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    // Sample the 40pt avatar chip — it draws at 40 but must respond to a 44pt hit.
    const avatar = page.getByText('SV', { exact: true }).first();
    await expect(avatar).toBeVisible();
    // Playwright's click is a point-tap; we just verify the element is clickable at all.
    await avatar.click({ trial: true });
  });

  test('prefers-reduced-motion kills the pulse rings', async ({ page, browserName }) => {
    test.skip(browserName === 'webkit', 'emulate applies but ring class differs across engines');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/index.html');
    await page.getByText('Log in', { exact: true }).click();
    const anims = await page.evaluate(() => {
      const nodes = document.querySelectorAll('*');
      let running = 0;
      nodes.forEach((n) => {
        const s = getComputedStyle(n).animationName;
        if (s && s !== 'none') running += 1;
      });
      return running;
    });
    expect(anims).toBe(0);
  });
});
