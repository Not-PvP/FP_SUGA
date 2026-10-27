# Debugging and performance with Flutter DevTools (Issue #19)

This file records what was checked, what was found, and what was changed. The
"Static review" section was done by reading the code for rebuild and request
patterns. The "DevTools session" section is a checklist to fill in while running
the app with DevTools, so the evidence (screenshots, numbers) can go into the
documentation paper.

## Static review: what was found and fixed

| # | Where | Finding | Why it matters | Fix |
|---|-------|---------|----------------|-----|
| 1 | `brownout_details_screen.dart` | The weather card was built with `FutureBuilder(future: AreaService().fetchAreas())` inside `build()`. | A new request to `/api/areas` (and a new weather request) was sent every time the screen rebuilt. The screen watches `PowerInterruptionProvider`, `AuthProvider` and `NotificationProvider`, and the notification clock notifies once a minute, so it refetched at least once a minute while open. | The future now lives in `_AdvisoryWeatherState` and is created once (`late final`). |
| 2 | `brownout_details_screen.dart` | Local helper functions started with an underscore (`_buildInfoSection`, `_formatTime`). | `flutter analyze` reports `no_leading_underscores_for_local_identifiers`. | Renamed. |

Patterns that were checked and are fine:

- Screens that need areas keep the `Future` in state (`AreasScreen`, `SettingsScreen`,
  `HomeScreen`, `AreaDetailsScreen`) instead of creating it in `build()`.
- `PowerInterruptionProvider.loadInterruptions()` shares one in-flight request, so
  several screens asking at once send one request.
- The bulb glow uses a gradient instead of a blur filter and stops when the phone's
  "remove animations" setting is on.
- Lists of advisories use cards that only read the advisory they were given.

Known limits, not changed:

- The admin "All advisories" list builds every row at once (it is a `Column` inside a
  `ListView`). That is fine for dozens of advisories. If the list grows into the
  hundreds, switch it to a lazy `SliverList`.
- `NotificationProvider` notifies every minute so countdown text stays fresh,
  even when nothing visible changed.

## DevTools session (to fill in on a device or emulator)

Run in **profile** mode, not debug, for timing numbers:

```bash
cd <repo root>
flutter run --profile
# then open DevTools from the link printed in the terminal
```

Record the result of each step. Take a screenshot for each one and save it in
`docs/devtools/` (for example `docs/devtools/01-rebuild-stats-home.png`).

| Step | DevTools tab | What to do | Result (fill in) |
|------|--------------|------------|------------------|
| 1 | Logging / Console | Start the app, open every tab, open an advisory, open Notifications. Look for red errors or exceptions. | |
| 2 | Network | Open an advisory details screen and leave it for 2+ minutes. Confirm `/api/areas` is requested once, not every minute (finding 1). | |
| 3 | Performance | Turn on "Track widget builds" and scroll the Scheduled list. Note any widget rebuilding far more than its neighbours. | |
| 4 | Performance | Record a frame timeline while switching tabs. Note frames over 16 ms. | |
| 5 | Memory | Open and close Area Details and Brownout Details 10 times, force a GC. Check the heap returns to a flat line (no growth from leaked listeners or controllers). | |
| 6 | Inspector | Check the widget tree of Home for unexpected duplicates of `PowerStatusWidget`. | |
| 7 | Logging | Turn off Wi-Fi, pull to refresh. Confirm the error panel appears and no unhandled exception is printed. | |

### Documenting one bug end to end (for the rubric)

Use finding 1 as the worked example:

1. **Symptom:** repeated `/api/areas` and weather requests while the details screen
   is open (Network tab, step 2).
2. **Cause:** a future created inside `build()`.
3. **Fix:** `_AdvisoryWeatherState` holds the future.
4. **Verification:** repeat step 2 and show a single request.

If a runtime error with a stack trace shows up in step 1 or 7, add its trace here
and describe the fix in the same four-part format.
