# CampusGuard Improvements

This document lists practical improvements based on the current repository state.

## 1. High-Priority Bug Fixes

### 1.1 Align claim status logic across schema and backend
- Current mismatch risk:
  - `lib/db/src/schema/claims.ts` comments `pending | verified | rejected`
  - Backend uses `accepted`, `rejected`, `verified`, and OTP workflow.
- Recommendation:
  - Standardize one canonical claim status state machine.
  - Update OpenAPI schema + backend DTO docs + Drizzle comments/enums together.

### 1.2 Ensure OpenAPI matches implemented claim endpoints
- Backend has endpoints like `/api/claims/{id}/accept`, `/reject`, `/generate-otp`, `/messages`.
- Recommendation:
  - Confirm all implemented routes are represented in `lib/api-spec/openapi.yaml`.
  - Regenerate clients after any route additions/changes.

### 1.3 Reduce route drift between generated hooks and custom hooks
- `lib/api-client-react/src/custom-hooks.ts` exists for extra endpoints.
- Recommendation:
  - Move as many endpoints as possible into OpenAPI + generated hooks.
  - Keep custom hooks only for temporary/non-spec operations.

## 2. Performance Improvements

### 2.1 Replace in-memory filtering/pagination with DB-level queries
- In controllers, some list operations fetch all rows and filter in Java streams.
- Recommendation:
  - Push filtering/pagination to repository query methods.
  - Avoid loading entire datasets for large item/claim tables.

### 2.2 Use aggregate queries for dashboard metrics
- Current admin stats build counts via multiple full fetches.
- Recommendation:
  - Use targeted count queries grouped by status/type.
  - Reduce query volume and memory overhead.

### 2.3 Introduce cache strategy for read-heavy endpoints
- Candidates: feed listing, categories, stats snapshots.
- Recommendation:
  - Use short TTL cache or query-level caching for hot reads.

## 3. Better Project Structure

### 3.1 Introduce explicit service layer in backend
- Controllers currently hold substantial business logic.
- Recommendation:
  - Add `service/` classes for auth, items, claims, admin workflows.
  - Keep controllers thin (validation + orchestration only).

### 3.2 Define architecture ownership boundaries
- Monorepo includes Java runtime backend and TypeScript DB/schema libs.
- Recommendation:
  - Add a short architecture contract doc clarifying:
    - Which schema is runtime source of truth.
    - How OpenAPI changes are versioned and propagated.

### 3.3 Consolidate environment variable docs
- Env vars are spread across `application.yml`, Vite config, and `render.yaml`.
- Recommendation:
  - Add an env matrix table (local/dev/prod) in docs and keep it updated.

## 4. Missing Features

### 4.1 Real AI chat integration
- `ChatController` currently returns mock responses.
- Recommendation:
  - Wire backend chat endpoint to `@workspace/integrations-openai-ai-server`.
  - Add usage limits and graceful fallbacks.

### 4.2 Email/SMS delivery for OTP and claim updates
- OTP is generated and stored but not externally delivered.
- Recommendation:
  - Integrate email/SMS provider for OTP delivery and status notifications.

### 4.3 Audit trail for moderation actions
- Admin actions (delete/flag) should be auditable.
- Recommendation:
  - Add an `admin_actions` table and immutable audit events.

## 5. Security Improvements

### 5.1 Remove insecure default JWT secret from runtime defaults
- `application.yml` includes a hardcoded fallback JWT secret.
- Recommendation:
  - Fail startup when `JWT_SECRET` is missing outside local dev profile.
  - Use dedicated environment profiles (`dev`, `prod`).

### 5.2 Harden CORS policy in production
- Render currently uses `ALLOWED_ORIGINS="*"` while credentials are enabled.
- Recommendation:
  - Restrict to explicit frontend origin(s).
  - Avoid wildcard with credentialed requests.

### 5.3 Strengthen auth/session protections
- Recommendation:
  - Add token refresh strategy or short-lived access + refresh tokens.
  - Consider secure cookie strategy for same-site deployments.
  - Add brute-force protection/rate limiting for auth routes.

### 5.4 Input/file upload safeguards
- Image upload currently converts base64 to data URI.
- Recommendation:
  - Enforce max size/content-type validation.
  - Move to object storage upload flow for scalability.

## 6. Testing Setup

### 6.1 Backend test baseline
- Add unit tests for services and integration tests for controllers.
- Focus first on auth, claim transitions, admin authorization.

### 6.2 Frontend test baseline
- Add component and hook tests for:
  - Auth provider/guard
  - Feed/report flows
  - Claim verification screens

### 6.3 Contract testing
- Add CI check to ensure OpenAPI, generated client, and runtime behavior stay synchronized.

### 6.4 CI pipeline
- Add GitHub Actions (or equivalent) for:
  - Install
  - Typecheck/build
  - Backend tests
  - Frontend tests
  - Optional OpenAPI diff validation

## 7. Logging and Monitoring

### 7.1 Structured logging
- Add request correlation IDs and structured JSON logs in backend.

### 7.2 Error reporting
- Integrate error tracking for frontend and backend.

### 7.3 API observability
- Add metrics/tracing for endpoint latency, error rate, and auth failures.

### 7.4 Security/audit observability
- Track suspicious claim patterns, repeated failed logins, and admin action rates.

## 8. Suggested Prioritized Execution Plan

1. Stabilize contracts and auth/security basics
2. Add backend service layer + query optimization
3. Add automated tests and CI
4. Implement real chat integration and notification delivery
5. Add logging/monitoring/audit trail
