# Phase 031 — Working-hours semantics

**Status:** In review. Verified (Dart + PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Dart and SQL must agree on unknown hours, closed days, all-day service, overnight spill, week boundaries, and India time.

## Changed paths
- `docs/contracts/fixtures/working-hours.json` (new): 13 boundary cases; the single source of truth.
- `lib/domain/models/provider.dart`:
  - `DayHours.containsMinutes`: an overnight window covers only its own day's part, and a close of 1439 means "until midnight";
  - `WorkingHours.isOpenAt`: always checks yesterday's spill;
  - `WorkingHours.indiaNow()` (new).
- `lib/core/widgets/provider_contact.dart` and `lib/data/repositories/mock_provider_repository.dart`: use `indiaNow()` instead of the device clock.
- `test/working_hours_contract_test.dart` (new): drives Dart from the fixture.
- Migration `…16`: `private.hours_open(today, yesterday, minute)`, used by the `search_providers` open-now filter.

## Rule
A window is in India wall-clock minutes. A window with close ≤ open runs overnight into the next day; open = close is a 24-hour window starting at open; a close of 1439 means "until midnight". Open now = today's own-day part ∪ yesterday's overnight tail. No rows = unknown: Dart returns null, and SQL never treats it as open-now.

## Bugs fixed
1. **SQL:** open-now looked only at today's row, so the overnight spill was missed. Example: Tue 22:00–02:00 was not open at Wed 01:00.
2. **Dart:** a day's own overnight window was counted as covering that day's early morning. Example: Tue 01:00 showed "open" even when Monday was closed.
3. **Dart:** used the device timezone, but listing hours are Indian local hours.
4. **Both:** an all-day 00:00–23:59 window was shown closed at 23:59.

## Verification
- `flutter test --no-pub test/working_hours_contract_test.dart` → `+13: All tests passed!`.
- The existing Dart overnight test still passes (Sat 22–02: open Sun 01:00, closed 03:00).
- `0012_search_bounds` runs all 13 fixture cases against `private.hours_open`.
- Full Flutter suite → `+74 ~1 -10`: the same 10 failures as before this work, and `~1` is the skipped draft-leak reproduction.

## Residual
- Holidays are not modelled (no data).
- The previous open-now filter is replaced, not removed, so "disable open-now until consistent" was not needed.
