# CampusGuard Codebase Guide

## 1. Main Business Logic

CampusGuard focuses on a lost-and-found lifecycle:

1. User authentication (register/login)
2. Item reporting (lost/found)
3. Claim submission by other users
4. Claim acceptance/rejection by item reporter
5. OTP generation and final verification for return
6. Admin moderation and analytics

Core backend controllers:
- `backend-java/src/main/java/com/collegeconnect/backend/controller/AuthController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/ItemController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/ClaimController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/AdminController.java`
- `backend-java/src/main/java/com/collegeconnect/backend/controller/ChatController.java`

Core frontend flows/pages:
- `artifacts/lost-and-found/src/pages/auth/*`
- `artifacts/lost-and-found/src/pages/feed/index.tsx`
- `artifacts/lost-and-found/src/pages/report/index.tsx`
- `artifacts/lost-and-found/src/pages/claim-verify.tsx`
- `artifacts/lost-and-found/src/pages/admin.tsx`
- `artifacts/lost-and-found/src/pages/chat.tsx`

## 2. Database Models / Schema

Two database layers exist in the repo:

1. Runtime backend persistence (Spring Data JPA entities in `backend-java/src/main/java/com/collegeconnect/backend/model/`)
2. Shared schema package via Drizzle (in `lib/db/src/schema/`), useful for typed contracts and tooling

Important Drizzle schema tables:

- `users` (`lib/db/src/schema/users.ts`)
  - `id`, `name`, `email`, `passwordHash`, `role`, `isAdmin`, `isVerified`, `createdAt`

- `items` (`lib/db/src/schema/items.ts`)
  - `id`, `type` (`lost`/`found`), `title`, `description`, `category`, `location`, `imageUrl`, `status`, `reportedBy`, `createdAt`

- `claims` (`lib/db/src/schema/claims.ts`)
  - `id`, `itemId`, `claimerId`, `message`, `otp`, `status`, `flagged`, `createdAt`, `verifiedAt`

Additional backend-side models include claim chat/messages and conversation records.

## 3. API Routes

### Health
- `GET /api/health`

### Auth
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`

### Items
- `GET /api/items`
- `POST /api/items`
- `GET /api/items/{id}`
- `DELETE /api/items/{id}`
- `POST /api/items/upload-image`

### Claims
- `GET /api/claims/my`
- `POST /api/claims`
- `POST /api/claims/{id}/accept`
- `POST /api/claims/{id}/reject`
- `POST /api/claims/{id}/verify`
- `POST /api/claims/{id}/generate-otp`
- `GET /api/claims/{id}/messages`
- `POST /api/claims/{id}/messages`

### Admin
- `GET /api/admin/stats`
- `GET /api/admin/items`
- `GET /api/admin/transactions`
- `DELETE /api/admin/items/{id}`
- `POST /api/admin/claims/{id}/flag`

### Chat
- `POST /api/chat/message`

OpenAPI source of truth:
- `lib/api-spec/openapi.yaml`

## 4. Authentication Flow

Backend auth:
- `SecurityConfig` configures stateless security, CORS, and route access.
- `JwtAuthenticationFilter` reads JWT from Authorization header or cookie and sets security context.
- `JwtTokenProvider` creates and validates JWT tokens.

Frontend auth:
- `use-auth.tsx` wraps generated hooks (`useGetCurrentUser`, `useLoginUser`, `useRegisterUser`, `useLogoutUser`).
- `main.tsx` sets `setAuthTokenGetter(() => localStorage.getItem("jwt_token"))`.
- `App.tsx` uses `ProtectedRoute` and `requireAdmin` checks.

Important detail:
- Backend sets an httpOnly cookie on login/register.
- Frontend also stores JWT token in localStorage for cross-origin Render deployments.

## 5. Frontend-Backend Communication

Communication path:

1. API contract authored in `lib/api-spec/openapi.yaml`
2. Orval config (`lib/api-spec/orval.config.ts`) generates:
   - React Query client hooks in `lib/api-client-react`
   - Zod schemas in `lib/api-zod`
3. Frontend pages call generated hooks.
4. `custom-fetch.ts` in `lib/api-client-react` handles:
   - Base URL overrides (`setBaseUrl`)
   - Bearer token injection (`setAuthTokenGetter`)
   - Error parsing and typed error behavior

Local dev transport:
- Vite proxies `/api` to `http://localhost:8080`

Production transport:
- `VITE_API_URL` points to deployed backend service URL.

## 6. Config Files You Should Know

- Workspace:
  - `package.json`
  - `pnpm-workspace.yaml`
  - `tsconfig.base.json`
  - `tsconfig.json`

- Frontend:
  - `artifacts/lost-and-found/vite.config.ts`
  - `artifacts/lost-and-found/src/main.tsx`
  - `artifacts/lost-and-found/src/App.tsx`

- Backend:
  - `backend-java/pom.xml`
  - `backend-java/src/main/resources/application.yml`
  - `backend-java/src/main/java/com/collegeconnect/backend/config/SecurityConfig.java`
  - `backend-java/Dockerfile`

- Shared libs:
  - `lib/api-spec/orval.config.ts`
  - `lib/db/drizzle.config.ts`

- Deployment:
  - `render.yaml`

## 7. Important Services and Utilities

### Frontend utilities
- `@workspace/api-client-react` generated hooks and fetch mutator
- Auth context in `artifacts/lost-and-found/src/hooks/use-auth.tsx`

### Backend utilities
- Security/JWT classes in `backend-java/src/main/java/com/collegeconnect/backend/security/`
- Repository interfaces in `backend-java/src/main/java/com/collegeconnect/backend/repository/`

### AI utilities
- `lib/integrations-openai-ai-server` provides OpenAI client wrappers for text/audio/image workflows
- Current `ChatController` is intentionally mocked for development

## 8. Known Architectural Notes

- The repo includes both Java JPA backend models and a TypeScript Drizzle schema package; this is useful for typed tooling but requires discipline to keep contracts aligned.
- OpenAPI codegen pipeline is central to frontend-backend consistency.
- Chat endpoint currently does not use live OpenAI in backend-java; integration package is available for future wiring.
