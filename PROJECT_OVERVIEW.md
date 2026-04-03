# CampusGuard Project Overview

## 1. What This Project Does

CampusGuard (also branded in code as College Connect) is a full-stack campus lost-and-found platform.

It allows users to:
- Register/login with college-style email addresses.
- Report lost/found items with metadata and optional image.
- Browse and filter item feeds.
- Submit claims for items.
- Coordinate return through claim chat and OTP-based verification.
- Access admin moderation and analytics features (for admin users).

The repository is a pnpm monorepo that combines frontend, backend, shared API/schema libraries, and deployment config.

## 2. Tech Stack

### Frontend
- Language: TypeScript
- Framework: React 19
- Build tool: Vite 7
- Styling/UI: Tailwind CSS 4 + Radix UI
- Routing: Wouter
- Data fetching/cache: TanStack React Query

### Backend
- Language: Java 21
- Framework: Spring Boot 3.2.4
- Security: Spring Security + JWT (JJWT)
- Persistence: Spring Data JPA / Hibernate
- Databases:
  - Local/default: H2 in-memory
  - Production: PostgreSQL

### Shared Libraries
- OpenAPI source and codegen: Orval
- Typed API client hooks: React Query client package
- Runtime schema validation: Zod package
- Database schema package: Drizzle ORM + PostgreSQL driver
- AI integration package: OpenAI SDK wrapper (server-side library package)

### Workspace/Tooling
- Monorepo/package manager: pnpm workspaces
- Type checking: TypeScript project references + workspace scripts
- Formatting: Prettier
- Deployment target: Render

## 3. Folder Structure (Major Folders)

- `artifacts/lost-and-found/`
  - Main React application (UI pages, components, hooks, layout, styling).
- `backend-java/`
  - Spring Boot API service (controllers, models, repositories, security, DTOs, config).
- `lib/api-spec/`
  - OpenAPI spec and Orval config used to generate typed clients/schemas.
- `lib/api-client-react/`
  - Generated and custom API client utilities/hooks for frontend usage.
- `lib/api-zod/`
  - Generated Zod schemas for request/response validation.
- `lib/db/`
  - Drizzle schema definitions and DB tooling scripts (`push`, `push-force`).
- `lib/integrations-openai-ai-server/`
  - Reusable server-side OpenAI integration package.
- `lib/integrations-openai-ai-react/`
  - React-facing AI integration package scaffold.
- `scripts/`
  - Utility scripts workspace.
- `attached_assets/`
  - Supplemental project assets.

## 4. Application Entry Points

### Frontend Entry
- `artifacts/lost-and-found/src/main.tsx`
  - Boots React app.
  - Configures API base URL from `VITE_API_URL` when present.
  - Injects JWT token getter (localStorage) into API client.

- `artifacts/lost-and-found/src/App.tsx`
  - Defines app router and protected/admin route handling.
  - Initializes React Query provider and auth context provider.

### Backend Entry
- `backend-java/src/main/java/com/collegeconnect/backend/CollegeConnectApplication.java`
  - Spring Boot main class.

## 5. How Components/Modules Interact

1. Frontend pages/components call hooks from `@workspace/api-client-react`.
2. API client sends requests to:
   - `/api/*` via Vite proxy in local development.
   - `VITE_API_URL` in deployed environments.
3. Spring Boot controllers process requests and persist/fetch data through JPA repositories.
4. Authenticated requests are validated by JWT filter/security context.
5. Shared API contracts are defined in `lib/api-spec/openapi.yaml`, then code-generated into client/schema packages.
6. Deployment wiring (`render.yaml`) connects frontend -> backend URL and backend -> managed PostgreSQL.

## 6. APIs, Services, and External Integrations

### Core Backend API Groups
- Health: `/api/health`
- Auth: `/api/auth/*` (register, login, logout, current user)
- Items: `/api/items/*` (list/create/get/delete/upload-image)
- Claims: `/api/claims/*` (create, accept/reject, generate OTP, verify, messages)
- Admin: `/api/admin/*` (stats, items, transactions, moderation actions)
- Chat: `/api/chat/message`

### API Contract and Client Generation
- Source contract: `lib/api-spec/openapi.yaml`
- Generator config: `lib/api-spec/orval.config.ts`
- Generated client package: `lib/api-client-react`
- Generated Zod schemas: `lib/api-zod`

### External Integrations
- OpenAI integration package exists at `lib/integrations-openai-ai-server`.
- Current Java `ChatController` returns a mock response in development by default.

## 7. Environment Variables

### Backend (`backend-java/src/main/resources/application.yml`)
- `PORT` (default `8080`)
- `DATABASE_URL` (default H2 in-memory URL)
- `DATABASE_USERNAME` (default `sa`)
- `DATABASE_PASSWORD` (default empty)
- `DATABASE_DRIVER` (default `org.h2.Driver`)
- `HIBERNATE_DIALECT` (default `org.hibernate.dialect.H2Dialect`)
- `JWT_SECRET` (dev default present; should be overridden in real environments)
- `JWT_EXPIRATION` (default `86400000` ms)
- `ALLOWED_ORIGINS` (default `http://localhost:5173,http://localhost:3000`)

### Frontend (`artifacts/lost-and-found/vite.config.ts` + app bootstrap)
- `VITE_API_URL` (optional; required for deployed frontend to call backend service directly)
- `PORT` (dev/preview server port, default `5173`)
- `BASE_PATH` (default `/`)

### AI Integration Package (when used)
- `AI_INTEGRATIONS_OPENAI_API_KEY`
- `AI_INTEGRATIONS_OPENAI_BASE_URL` (optional override)

## 8. How To Run Locally

Prerequisites:
- Node.js (current LTS recommended)
- pnpm
- Java 21
- Maven (or use bundled Maven binary inside `backend-java/apache-maven-3.9.6/bin`)

Install dependencies from repo root:

```bash
pnpm install
```

Run frontend (terminal 1):

```bash
cd artifacts/lost-and-found
pnpm run dev
```

Run backend (terminal 2):

```bash
cd backend-java
mvn clean package -DskipTests
java -jar target/*.jar
```

Windows fallback using bundled Maven:

```powershell
cd backend-java
.\apache-maven-3.9.6\bin\mvn.cmd clean package -DskipTests
java -jar target\*.jar
```

Default local URLs:
- Frontend: `http://localhost:5173`
- Backend: `http://localhost:8080`

Note:
- Vite proxies `/api` to the backend in local dev.
- Backend can run against in-memory H2 by default; PostgreSQL env values are required for production-like DB behavior.

## 9. Build and Deployment Process

### Workspace Build
From repo root:

```bash
pnpm run build
```

This runs type checks and package builds across the workspace.

### Render Deployment (`render.yaml`)
The deployment defines three services:

1. `college-connect-db` (managed PostgreSQL database)
2. `college-connect-api` (Dockerized Spring Boot backend from `backend-java/`)
3. `college-connect-ui` (static React site built from workspace root)

Frontend build command on Render:

```bash
pnpm install && pnpm run build --filter @workspace/lost-and-found
```

Static publish path:
- `artifacts/lost-and-found/dist/public`

Backend service receives DB and auth env vars from Render wiring.
Frontend receives `VITE_API_URL` from backend service `hostWithScheme`.

## 10. Current Observations

- The codebase already has strong separation between UI, API service, and shared API/schema libraries.
- API generation flow (OpenAPI -> Orval -> typed client/schemas) is a key maintainability asset.
- Chat route in Java backend is currently mocked; the OpenAI integration package exists but is not yet wired into the Spring controller flow.