# Search Source Research

Date: 2026-05-06

## Summary

V2Next should keep in-app topic search local-first for now. The current official V2EX API 2.0 Beta page lists notifications, member, token, node detail, node topics, topic detail, topic replies, and guarded topic actions, but no topic-search endpoint.

## Sources Checked

- Official API 2.0 Beta: https://www.v2ex.com/help/api
  - Last updated on the page: 2026-04-17 04:26:02 +0000.
  - Relevant finding: API endpoints include `nodes/:node_name/topics`, `topics/:topic_id`, and `topics/:topic_id/replies`; there is no search endpoint.
- Historical V2EX search discussions:
  - https://www.v2ex.com/t/445957 describes the site search redirecting to external search with `site:v2ex.com/t`.
  - https://www.v2ex.com/t/218562 includes examples of Google site search forms/queries for V2EX.

## Product Decision

- Do not parse Google/Bing/360 result pages inside the app. It is brittle, can fail by region/login/captcha, and would make failures look like app failures.
- Keep `localWithNodes` as the default source because it is deterministic and fast enough for client-side use.
- The "remote" source is an external-open action: the app opens a browser search for `site:v2ex.com/t <query>` and does not parse or merge remote results.
- If an official V2EX topic-search API appears later, add it behind the existing `SearchSettings.sourceMode` shape instead of coupling it directly into `SearchPage`.

## Implementation Boundary

Current source modes:

- `local`: saved topics, viewed topics, saved nodes, offline cache.
- `localWithNodes`: local plus the public all-nodes index.
- `externalWeb`: opens the system browser with a Bing site-search query and does not merge results into the app list.
