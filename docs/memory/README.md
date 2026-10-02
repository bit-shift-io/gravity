# Repo Memory

Situational facts: true only when touching a particular area. One fact per file.

- [love-11-and-12-compat.md](love-11-and-12-compat.md) — must run on LÖVE 11.5 and 12; version-sensitive calls go through `src/app/compat.lua`
- [test-framework-from-fido-and-kitch.md](test-framework-from-fido-and-kitch.md) — test tiers are ported from `~/Projects/fido-and-kitch`; what to keep and strip
- [v1-pending-slices-predate-tank-mode.md](v1-pending-slices-predate-tank-mode.md) — remaining v1 slices use pre-tank-mode mechanics; how to read them
- [asteroid-contact-handling-order.md](asteroid-contact-handling-order.md) — blast push must run before asteroid split; one split per asteroid per step
- [fragments-cling-under-gravity.md](fragments-cling-under-gravity.md) — sibling immunity lasts while fragments touch; force separation by hand in tests
