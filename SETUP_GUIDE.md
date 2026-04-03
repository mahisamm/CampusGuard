# CampusGuard Setup Guide

This guide is for new developers setting up CampusGuard from scratch.

## 1. Prerequisites

Install the following first:
- Git
- Node.js LTS (18+; 20+ recommended)
- pnpm (`npm i -g pnpm`)
- Java 21 (JDK)
- Maven 3.9+ (optional if you use bundled Maven in `backend-java/apache-maven-3.9.6/bin`)

Optional for production-like local DB:
- PostgreSQL 14+

## 2. Clone and Install

From your workspace root:

```bash
git clone <repo-url>
cd CampusGuard
pnpm install
```

## 3. Environment Configuration

### Backend defaults (works without extra env)
`backend-java/src/main/resources/application.yml` includes defaults:
- H2 in-memory DB
- `PORT=8080`
- local CORS origins

### Backend production-like env (optional)
Set these before running backend if using PostgreSQL:
- `DATABASE_URL`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `DATABASE_DRIVER=org.postgresql.Driver`
- `HIBERNATE_DIALECT=org.hibernate.dialect.PostgreSQLDialect`
- `JWT_SECRET`
- `ALLOWED_ORIGINS`

### Frontend env
- `VITE_API_URL` is optional in local dev (Vite proxy handles `/api`).
- Set `VITE_API_URL` when the frontend and backend are not on the same origin/proxy.

## 4. Run Locally (Recommended)

Open two terminals.

### Terminal 1: Frontend

```bash
cd artifacts/lost-and-found
pnpm run dev
```

### Terminal 2: Backend

```bash
cd backend-java
mvn clean package -DskipTests
java -jar target/*.jar
```

Windows bundled Maven option:

```powershell
cd backend-java
.\apache-maven-3.9.6\bin\mvn.cmd clean package -DskipTests
java -jar target\*.jar
```

Expected URLs:
- Frontend: `http://localhost:5173`
- Backend: `http://localhost:8080`
- Health check: `http://localhost:8080/api/health`

## 5. Workspace Build and Typecheck

From repo root:

```bash
pnpm run typecheck
pnpm run build
```

## 6. Regenerate API Client/Schemas (when OpenAPI changes)

From repo root:

```bash
pnpm --filter @workspace/api-spec run codegen
```

This regenerates artifacts in:
- `lib/api-client-react/src/generated/`
- `lib/api-zod/src/generated/`

## 7. Database Schema Tooling (Drizzle Package)

The `@workspace/db` package requires `DATABASE_URL`.

Commands:

```bash
pnpm --filter @workspace/db run push
pnpm --filter @workspace/db run push-force
```

Note:
- `push-force` can be destructive. Use cautiously.

## 8. Render Deployment Basics

`render.yaml` defines:
- PostgreSQL service (`college-connect-db`)
- Backend web service (`college-connect-api`) built from Dockerfile
- Frontend static service (`college-connect-ui`) built via pnpm workspace command

Render injects service connection env vars (DB values and `VITE_API_URL`) automatically.

## 9. Troubleshooting

### Frontend cannot reach backend
- Confirm backend is running on port 8080.
- Check Vite proxy config in `artifacts/lost-and-found/vite.config.ts`.
- If not using proxy, set correct `VITE_API_URL`.

### 401 unauthorized in frontend
- Login again and verify `jwt_token` is present in localStorage.
- Verify backend CORS allows your frontend origin.

### Maven command not found
- Use bundled command:
  - `backend-java/apache-maven-3.9.6/bin/mvn.cmd`

### DB connection errors with PostgreSQL mode
- Verify `DATABASE_URL`, username/password, driver, and dialect values.
- For a quick local start, fall back to H2 defaults by unsetting DB env vars.

### API mismatch after endpoint changes
- Re-run codegen for `@workspace/api-spec` and rebuild.
