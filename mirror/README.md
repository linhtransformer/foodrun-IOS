# mirror/

HTML mirror + Playwright specs for the Foodrun iOS worker app design system.

`index.html` is the bundle's `Foodrun iOS App.dc.html` copied verbatim. It renders inside
a 402x874pt iPhone frame in any modern browser and is the visual + interaction spec that
the SwiftUI aims to match.

`current-build-baseline.html` is what the repo built **before** this design system was
applied (AuthView + HomeView showcase). Kept for before/after comparison.

`HANDOFF.md` is the full 530-line design spec from the bundle.

## Run the mirror

```
npm install
npm run install-browsers
npm run serve
```

Open http://127.0.0.1:4321/index.html — click through Sign in → Shifts → all 8 screens.

## Run the tests

```
npm test          # headless
npm run test:ui   # interactive UI mode
```

The specs assert the design contract — tab bar reachability, hero collapse/expand,
mode-pill switching, Dutch-formatted hours (`6,3 h`), NFC flash timing, checklist gate,
reduce-motion. When SwiftUI drifts from the mirror, expect specs to still pass — they
verify the mirror. The Swift code has its own `#Preview` blocks and Mac-side compile
checks.

## What Playwright cannot verify

- SwiftUI compilation.
- UIKit rendering differences on real iPhone hardware.
- Core NFC behaviour (real reads, background reads).
- Live Activities / Widget extension output.

Those still need a Mac + device.
