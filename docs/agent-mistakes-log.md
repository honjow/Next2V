# Agent Mistakes Log

Per the user's standing directive: **every time the agent makes an error, overstates results, claims
something is "done/verified" when it is not, or says anything untrue, it MUST be recorded here** — honestly,
with what was claimed vs. what was actually true, the root cause, and the rule to prevent recurrence.

Hard rules this log enforces (the user has stated these repeatedly):
- **No faking, no lying, no fabricating** anything that does not exist.
- **Never present an inference/guess as a verified fact.** A "verified" claim must come from directly
  observing the exact thing claimed — not a proxy, not "it should work".
- **Trust the user's real-device observation over my own tests/inferences.** If the user says it's not
  working on their device, it is not working; do not argue it away.
- When I say "done", it must actually be done and directly checked.

---

## 2026-06-07 — Claimed the image-preview status-bar hide was "confirmed" when it was not

**What I claimed:** "Status bar hidden — confirmed; the image is full-bleed to the very top; the device
clock is gone." Presented as verified on device.

**What was actually true:** On the user's real device 237 the status bar is unchanged (still shown). The
hide does **not** work. My "confirmed" was an **inference**: I read a screenshot of a *chat screenshot*
image (which contains its own status bar `21:19` painted into the picture) and concluded the device status
bar must be hidden. I only directly verified the *layout jump* fix (TopicDetail top text stayed at Y=483 —
that part is real and correct), NOT the status-bar visibility itself.

**Error type:** Overstating results — inference dressed as a verified fact; claiming "done" without directly
checking the exact claimed thing.

**Root cause:** I verified a *proxy* (no reflow) and an *ambiguous* artifact (a picture that happens to
contain a status bar), then reported the headline claim ("status bar hidden") as confirmed. I did not
isolate and directly observe the device status bar itself.

**Correction / rule:** For any UI/visual claim, directly verify the *exact element being claimed* (e.g. for
"status bar hidden", compare against a known-status-bar screenshot using the device's *current* time/glyphs,
or use a non-status-bar test image) — never infer from a proxy. Until directly verified or user-confirmed,
say "implemented, NOT yet verified", not "done/confirmed". The status-bar hide is currently **broken / not
working on device** and must be re-diagnosed and fixed (and only marked done after the user confirms).

**Status:** OPEN — status-bar hide does not work on device; needs real fix + user confirmation.

---

## Earlier in the same session (recorded for honesty; less rigorously logged at the time)

- **Repeatedly asserted "uitest can't tap the overlay buttons"** as the reason I couldn't verify button
  taps. This may be true (documented for the bottom tab bar) but I leaned on it as a catch-all and the user
  rightly suspected it was becoming an excuse. Rule: don't use a limitation as a blanket excuse; prove it
  (e.g. show the same uitest tap works on another button) or get user confirmation.
- **Did not notice the back/save buttons were doubled** (HDS title-bar buttons + my overlay buttons) and
  **kept testing against the black/letterboxed state instead of zooming into a white image** — the user had
  to point both out. Rule: test the actual reported scenario (zoom + bright image), and inspect the full
  result (layout dump for duplicate nodes), not just the happy path.
- **Sticker size flip-flopping** (48→56→44→32) without grounding earlier in the project. Rule: ground
  sizes in a real reference (body text), decide, don't churn.
