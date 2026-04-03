# Architecture Analysis

This document captures Phase 1 analysis for production-style separation of CampusGuard into frontend, backend API, and database services.

## 1. Current Repository Architecture

CampusGuard is currently a pnpm monorepo with these major areas:

- `artifacts/lost-and-found/`: React frontend app
- `backend-java/`: Spring Boot backend API
- `lib/`: shared/generated API, schema, DB tooling, integrations
- `render.yaml`: deployment definition for DB + API + static UI
- workspace root scripts for typecheck/build orchestration

The codebase is already logically separated by concern, but not yet physically restructured into top-level `frontend/` and `backend/` directories.

## 2. Frontend Code Location

Primary frontend location:

- `artifacts/lost-and-found/`

Frontend entry points:

- `artifacts/lost-and-found/src/main.tsx` (bootstrap, API base URL setup, auth token getter wiring)
- `artifacts/lost-and-found/src/App.tsx` (routing, providers, protected routes)

Frontend runtime/build config:

- `artifacts/lost-and-found/vite.config.ts` (Vite, proxy, output path, aliases)
- `artifacts/lost-and-found/package.json` (dev/build/serve/typecheck scripts)

Frontend features live under:

- `artifacts/lost-and-found/src/pages/`
- `artifacts/lost-and-found/src/components/`
- `artifacts/lost-and-found/src/hooks/`
- `artifacts/lost-and-found/src/lib/`

## 3. Backend Code Location

Primary backend location:

- `backend-java/`

Backend entry point:

- `backend-java/src/main/java/com/collegeconnect/backend/CollegeConnectApplication.java`

Backend API/business/auth locations:

- `backend-java/src/main/java/com/collegeconnect/backend/controller/`
- `backend-java/src/main/java/com/collegeconnect/backend/model/`
- `backend-java/src/main/java/com/collegeconnect/backend/repository/`
- `backend-java/src/main/java/com/collegeconnect/backend/dto/`
- `backend-java/src/main/java/com/collegeconnect/backend/security/`
- `backend-java/src/main/java/com/collegeconnect/backend/config/`

Backend config and build:

- `backend-java/src/main/resources/application.yml`
- `backend-java/pom.xml`
- `backend-java/Dockerfile`

## 4. Database Usage

Runtime backend persistence:

- Spring Data JPA/Hibernate entities and repositories in `backend-java/.../model` and `backend-java/.../repository`

Database targets:

- Local default: H2 in-memory (`application.yml` defaults)
- Production target: PostgreSQL (via env vars and Render database service)

Additional typed schema/tooling package:

- `lib/db/src/schema/` (Drizzle schema files)
- `lib/db/drizzle.config.ts`

Important note:

- There are two schema representations (JPA entities and Drizzle schema package). This is workable but must be kept aligned to avoid contract drift.

## 5. Environment Variables (Current)

Backend env vars (`backend-java/src/main/resources/application.yml`):

- `PORT`
- `DATABASE_URL`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `DATABASE_DRIVER`
- `HIBERNATE_DIALECT`
- `JWT_SECRET`
- `JWT_EXPIRATION`
- `ALLOWED_ORIGINS`

Frontend env vars (`artifacts/lost-and-found/vite.config.ts`, `src/main.tsx`):

- `VITE_API_URL`
- `PORT`
- `BASE_PATH`

Integration package env vars:

- `AI_INTEGRATIONS_OPENAI_API_KEY`
- `AI_INTEGRATIONS_OPENAI_BASE_URL`

Deployment wiring source:

- `render.yaml` injects DB credentials, JWT secret, CORS settings, and frontend API URL.

## 6. API Routes (Current Backend Surface)

Route groups implemented in Java controllers:

- Health: `/api/health`
- Auth: `/api/auth/*`
- Items: `/api/items*`
- Claims: `/api/claims*`
- Admin: `/api/admin/*`
- Chat: `/api/chat/message`

Primary route sources:

- `backend-java/src/main/java/com/collegeconnect/backend/controller/HealthController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/AuthController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/ItemController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/ClaimController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/AdminController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/ChatController.java`

Contract/source-of-truth for generated client:

- `lib/api-spec/openapi.yaml`

## 7. Build Process and Entry Commands

Workspace root:

- `pnpm run typecheck`
- `pnpm run build`

Frontend:

- `pnpm run dev` (in `artifacts/lost-and-found`)
- `pnpm run build`
- `pnpm run serve`

Backend:

- `mvn clean package -DskipTests` (in `backend-java`)
- `java -jar target/*.jar`

Deployment currently modeled in:

- `render.yaml` (PostgreSQL + Dockerized backend + static frontend site)

## 8. Key Dependencies by Tier

Frontend:

- React 19, Vite 7, TypeScript
- TanStack React Query
- Wouter
- Tailwind CSS + Radix UI
- `@workspace/api-client-react`

Backend:

- Spring Boot 3.2.4
- Spring Security
- Spring Data JPA/Hibernate
- JJWT
- H2 and PostgreSQL drivers

Shared/libs:

- OpenAPI + Orval (`lib/api-spec`)
- generated API hooks (`lib/api-client-react`)
- generated Zod schemas (`lib/api-zod`)
- Drizzle schema/tooling (`lib/db`)
- OpenAI integration packages (`lib/integrations-openai-ai-*`)

## 9. Current Frontend-Backend Communication

Local development flow:

1. Frontend runs on Vite dev server (`localhost:5173`).
2. Frontend requests `/api/*`.
3. Vite proxy forwards `/api` to backend (`localhost:8080`).

Production-style flow:

1. Frontend uses `VITE_API_URL` to call backend over HTTPS.
2. Backend validates JWT from Authorization header (and cookie fallback).
3. CORS controlled by `ALLOWED_ORIGINS`.

Auth token behavior:

- Backend sets httpOnly cookie on auth endpoints.
- Frontend also stores JWT in localStorage and injects it via generated client fetch mutator for cross-origin scenarios.

## 10. What Must Be Separated for Target Architecture

Target architecture requested:

- Frontend on Vercel
- Backend API on Render
- PostgreSQL on Render

Required separation actions:

1. Move frontend app into `frontend/` top-level package.
2. Move backend Java service into `backend/` top-level package.
3. Keep shared contracts/tooling in backend-owned or shared space with clear ownership (OpenAPI, generated clients, schema tooling).
4. Replace current local-proxy assumptions with explicit environment-driven API URL in frontend production config.
5. Harden CORS to allow Vercel frontend origin(s) rather than wildcard.
6. Provide dedicated env examples and deployment docs for both tiers.

## 11. Frontend vs Backend Ownership Map

Belongs to frontend:

- `artifacts/lost-and-found/**`
- frontend-only static assets and UI config files
- client routing/components/hooks/styles

Belongs to backend:

- `backend-java/**`
- API controllers, auth/security, JPA models/repos, Spring config, Docker image build

Shared/contract layer (must be assigned carefully in restructure):

- `lib/api-spec/**`
- `lib/api-client-react/**`
- `lib/api-zod/**`
- `lib/db/**`
- `lib/integrations-openai-ai-*`

Recommendation for production split:

- Keep frontend consuming published/generated API client artifacts.
- Keep backend owning OpenAPI contract and server runtime models.
- Treat DB schema tooling as backend-adjacent unless actively used by frontend build/runtime.

## 12. Phase 1 Conclusion

The repository already has clean logical boundaries. The main work for the requested production architecture is physical restructuring plus deployment/environment hardening:

- map `artifacts/lost-and-found` -> `frontend/`
- map `backend-java` -> `backend/`
- preserve API contract/codegen workflow while avoiding duplicated schema ownership
- standardize env management and deployment docs for Vercel + Render + Render PostgreSQL

Phase 1 deliverable completed: `ARCHITECTURE_ANALYSIS.md`.
