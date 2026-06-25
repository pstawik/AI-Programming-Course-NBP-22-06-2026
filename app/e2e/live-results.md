# Live E2E Test Results

**Date:** 2026-06-25
**Tester:** QA Engineer (Claude)
**Branch:** worktree-poc-implementation-plan

---

## Step 5.1 — Contract Reconciliation Findings

### Stack Status

| Service | URL | Status |
|---|---|---|
| Backend (Spring Boot) | http://localhost:8080 | `/actuator/health` → `{"status":"UP"}` |
| Frontend (Angular) | http://localhost:4200 | Serving correctly, proxy active |
| Proxy `/api` → `:8080` | via proxy.conf.json | CORS headers returned by backend (`access-control-allow-origin: http://localhost:4200`) |

### Contract Verification Results

| Endpoint | Expected | Actual | Match |
|---|---|---|---|
| `GET /actuator/health` | 200 `{"status":"UP"}` | 200 `{"status":"UP"}` | MATCH |
| `POST /api/cases` (multipart) | 201 `{sessionId, outcome, decisionMessageMarkdown, decision}` | **404 Not Found** | **MISMATCH — BUG** |
| `GET /api/cases/{id}` | 200 `{sessionId, decision, messages[]}` or 404 with `{code, message}` | 404 Spring default format (no `code` field) | **MISMATCH — BUG** |
| `POST /api/cases/{id}/messages` | 200 SSE stream | Not tested (blocked by POST /api/cases bug) | Not tested |

### Root Cause — Backend Bug (POST /api/cases returns 404)

**Issue:** The backend running on port 8080 (PID 9056, started ~10:28 AM) was started
BEFORE the web controller code (`CaseController`, `ChatController`, `GlobalExceptionHandler`)
was compiled. The JVM loaded the application without these controllers, so Spring MVC
has no mapping for `POST /api/cases`.

**Evidence:**
- `CaseController.class` in `target/classes` has timestamp 13:17 (compiled AFTER startup).
- Backend app.log confirms PID 9056 started at 10:28:46 with "Nothing to compile — all classes up to date" (meaning the then-current classes, which did NOT include controllers).
- `POST /api/cases` returns Spring Boot's default `{"timestamp":..., "status":404, ...}` format — not our custom `ErrorDto` (which would have `code` + `message`).

**Fix Required:** Kill PID 9056 and restart the backend. The `.class` files in `target/classes` are up-to-date and include all controllers. The OPENROUTER_API_KEY from `.env` must be passed as env var.

**Command to fix (run manually):**
```
# Kill PID 9056 first (taskkill /PID 9056 /F)
# Then from app/backend:
OPENROUTER_API_KEY=<from .env> OPENROUTER_BASE_URL=https://openrouter.ai/api/v1 \
OPENROUTER_TEXT_MODEL=openai/gpt-4o-mini OPENROUTER_VISION_MODEL=openai/gpt-4o-mini \
./mvnw spring-boot:run
```

### Other Contract Observations

- `GET /api/cases/{unknown-uuid}` returns HTTP 404 with Spring Boot default error body,
  NOT our `{code: "SESSION_NOT_FOUND", message: "..."}`. This is consistent with the
  missing `GlobalExceptionHandler` — same root cause.
- The frontend correctly handles the 404 on session rehydration by redirecting to `/`.
- Proxy forwarding works: CORS headers present on all `/api` responses.
- The frontend `purchase date` field uses `ng.getComponent` to programmatically set dates —
  the MatDatepicker text input is locale-dependent (`5/25/2026` format on this machine, not `25.05.2026`).
  The E2E helpers address this via Angular form control access.

---

## Step 5.2 — Playwright E2E Scaffolding

### Setup Completed

| Item | Status |
|---|---|
| `app/e2e/package.json` | Created |
| `app/e2e/playwright.config.ts` | Created |
| `app/e2e/tsconfig.json` | Created |
| `app/e2e/fixtures/test-image.png` (1x1 white PNG) | Created |
| `app/e2e/fixtures/test-bad.gif` (minimal GIF for type rejection) | Created |
| `app/e2e/fixtures/intake-helpers.ts` | Created |
| `@playwright/test` installed | Yes (v1.49.x) |
| Chromium browser installed | Yes |

### Tests Written

| File | Tests | Description |
|---|---|---|
| `tests/validation.spec.ts` | 5 | Client-side form validation (no LLM required) |
| `tests/happy-path.spec.ts` | 3 | Full form → decision → chat flow (LLM required) |
| `tests/escalation.spec.ts` | 4 | Session guard, WYMAGA_WERYFIKACJI, disclaimer, markdown |

---

## Step 5.2 — Test Results (Current Backend State)

### Validation Tests (no LLM needed) — ALL PASS

| Test | Result |
|---|---|
| Missing reason for COMPLAINT shows inline error | PASS |
| Future purchaseDate blocked by datepicker | PASS |
| Uploading disallowed image type shows inline error | PASS |
| Oversize image shows inline error | PASS |
| Form prevents submit when no image attached | PASS |

### Session Guard Test — PASS (with caveat)

| Test | Result | Note |
|---|---|---|
| Direct /chat/:nonexistent redirects to / | PASS | Backend returns 404 (wrong format but frontend handles it) |

### Happy Path Tests — NOT RUN (blocked by backend bug)

The `POST /api/cases` route returns 404. Happy path tests that require the AI pipeline
cannot complete until the backend is restarted.

---

## Step 5.3 — Live Happy-Path Verification

**Status:** BLOCKED — Backend must be restarted (see Bug Report above).

Once the backend is restarted with the correct classpath and API key:
1. Run `npm test` from `app/e2e/`
2. Tests will call `POST /api/cases` with real OpenRouter key
3. Verify: decision bubble has `## Decyzja:` heading, justification, next steps, disclaimer
4. Send follow-up message and verify streaming

---

## Bugs Found

### BUG-E2E-001 — Critical

**Title:** Backend `POST /api/cases` returns 404 (controllers not loaded)

**Severity:** Critical — blocks all integration and E2E testing of the full flow

**Endpoint:** `POST /api/cases` (multipart/form-data)

**Repro:**
1. Start backend with `./mvnw spring-boot:run` (let it start on 8080)
2. Compile the web controllers AFTER startup (e.g., via a second failed mvnw run)
3. `POST /api/cases` with valid multipart form → 404

**Expected:** 201 `{sessionId, outcome, decisionMessageMarkdown, decision}`

**Actual:** 404 `{"timestamp":..., "status":404, "error":"Not Found", "path":"/api/cases"}`

**Root Cause:** JVM does not hot-reload new `.class` files after startup. The backend
must be restarted to pick up the newly compiled controllers.

**Fix:** Restart the backend process. The controller code is correct and compiles cleanly.
No code changes needed.

### BUG-E2E-002 — Minor

**Title:** `GET /api/cases/{unknown}` returns Spring Boot default 404 format, not our ErrorDto

**Severity:** Minor — frontend handles it correctly, but contract says `{code, message}`

**Expected:** `{"code":"SESSION_NOT_FOUND","message":"Sesja ..."}` with status 404

**Actual:** `{"timestamp":"...","status":404,"error":"Not Found","path":"..."}` with status 404

**Root Cause:** Same as BUG-E2E-001 — `GlobalExceptionHandler` not loaded.

**Fix:** Restart the backend.

---

## Notes

- No secrets are committed. The `.env` file with API keys is in `.gitignore`.
- The test fixture image is a valid 1×1 PNG (70 bytes); it produces no useful visual
  content for the LLM but is sufficient to pass validation and exercise the pipeline.
- For more realistic live testing, replace `fixtures/test-image.png` with an actual
  device photo.
