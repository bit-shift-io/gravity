---
name: register-new-test-files
description: New test files must be added to the run lists in tests/unit/run.lua and tests/integration/run.lua
metadata:
  type: convention
---

**Why:** The runners execute a fixed list of files, not a glob. An unregistered test file never runs and never fails, so its coverage is imaginary. `roster_test.lua` went unrun this way until it was registered.

**How to apply:** Whenever you create a `*_test.lua` under `tests/unit/` or `tests/integration/`, add it to the matching `run.lua` list in the same change, then confirm the test count rose. e2e files are discovered by `test-e2e.sh`, so they need no registration.
