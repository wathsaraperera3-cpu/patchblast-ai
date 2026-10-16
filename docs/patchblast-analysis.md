# PatchBlast AI implementation notes

## Jac graph and traversal

The backend persists `Asset` nodes and typed `Dependency` edges on Jac's graph root (SQLite-backed `.jac/data` by default). `_seed_graph` is idempotent by stable asset IDs. `DiscoverGraph` is a Jac walker that traverses typed edges and tracks visited asset IDs, so cycles terminate. `_dfs` preserves full application-to-component paths and also guards each path against revisiting an ID. Direct and transitive paths use the same deterministic version evaluator.

Remediation versions are scenario overrides passed to analysis, not mutations of baseline persisted nodes. This ensures the selected component record changes only in the simulation and reset returns seeded baseline versions. For `auth-acme` => `2.4.0`, Customer Portal/Auth API no longer matches; Checkout's distinct AcmeAuth dependency remains at `2.3.1`.

## AI runtime and limitations

Jac 0.34.23 includes native `by llm()` and the project already configures `gpt-4o-mini` plus `${OPENAI_API_KEY:-}`. There was no configured `OPENAI_API_KEY` in the inspected environment. An LLM response therefore cannot be relied on in the preview and is not invoked. The four UI roles are accurately labeled deterministic agent-style Jac stages. Version comparisons and traversal remain deterministic; no model is allowed to invent inventory or override version checks. To add a real evidence interpretation/remediation summary in a permitted environment, add the team's own key in JacHammer Settings > Environment, restart preview, then implement a typed `by llm()` summary with a deterministic fallback. This build does not claim model inference.

## Report

`getReport` builds JSON from the current recalculated state in Jac. The client downloads that string as `patchblast-investigation.json` using a browser Blob URL.

## Tests

Run `jac test services/patchblastService.jac -v`. The suite covers direct/transitive paths, a fixed version and unrelated package, unknown inventory, cycle termination, isolated scenario upgrade, reset, and report consistency. Jac tests share persisted graph data; `jac clean --all --force` before the suite yields an isolated store when needed.

## Jac language ratio

Counted reproducibly with `find` + `wc -l` in the project root, excluding generated `.jac/` and `.pytest_cache/`. Per-file counts: `services/patchblastService.jac` 270 Jac; `services/patchblastService.test.jac` 77 Jac; `components/PatchBlastDashboard.jac` 80 Jac; `components/ui/badge.jac` 51 Jac; `components/ui/button.jac` 84 Jac; `components/ui/card.jac` 93 Jac; `components/ui/input.jac` 14 Jac; `components/ui/native_select.jac` 60 Jac; `components/ui/skeleton.jac` 11 Jac; `lib/utils.jac` 6 Jac; `main.jac` 8 Jac. Jac total: 754 lines. CSS: 129; TOML: 95. Code denominator (Jac+CSS+TOML) is 978 lines; Jac share **77.1%**. Including README and docs, denominator is 1070; share **70.5%**. Managed shadcn UI makes up 301 Jac lines. These measured ratios do not reach 80%; do not inflate counts. Check the contest's official counting policy before claiming compliance.

## Verification notes

Six Jac tests passed on the latest run. Browser validation passed desktop and phone rendering/no-overflow after restarting preview. Browser interaction and JSON download were not confirmed end-to-end. `jac check` currently reports missing static type stubs for browser `Blob`/`URL` globals, although browser rendering itself validates without JS errors. Do not use `jac clean --all` while the preview server is running: it removes shared graph data; restart preview after graph data cleanup.
