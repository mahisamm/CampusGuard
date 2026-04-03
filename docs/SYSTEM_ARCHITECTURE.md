# System Architecture

Complete overview of CampusGuard production architecture and component interactions.

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Vercel CDN                                   │
│  Frontend React App (Static Files + Nginx)                      │
│  https://app.yourdomain.com                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTPS API Calls
                         │ (CORS enabled)
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Render Container                             │
│  Spring Boot Backend API (Docker + Java 21)                     │
│  https://college-connect-api.onrender.com                       │
│                                                                 │
│  Routes:                                                        │
│  - /api/auth/* (login, register, logout, me)                   │
│  - /api/items/* (list, create, get, delete, upload-image)      │
│  - /api/claims/* (create, accept, reject, verify, messages)    │
│  - /api/admin/* (stats, moderation)                             │
│  - /api/chat/message (AI support)                               │
│  - /api/health (liveness)                                       │
└────────────────────────┬────────────────────────────────────────┘
                         │ JDBC Connection
                         │ (PostgreSQL wire protocol)
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Render PostgreSQL                            │
│  college_connect database                                       │
│  college_admin user                                             │
│                                                                 │
│  Tables:                                                        │
│  - users (accounts, roles, auth)                               │
│  - items (lost/found posts)                                     │
│  - claims (item claims, OTP verification)                       │
│  - messages (claim chat)                                        │
│  - conversations (admin chat)                                   │
│  - otps (OTP records)                                           │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Technology Stack

### Frontend (Vercel)
- **Language**: TypeScript
- **Framework**: React 19
- **Build Tool**: Vite 7
- **Styling**: Tailwind CSS 4 + Radix UI
- **Routing**: Wouter (client-side)
- **Data Fetching**: TanStack React Query
- **API Client**: Generated from OpenAPI via Orval
- **Server**: Nginx (SPA routing + static asset caching)

### Backend (Render)
- **Language**: Java 21
- **Framework**: Spring Boot 3.2.4
- **Security**: Spring Security + JWT (JJWT)
- **ORM**: Spring Data JPA + Hibernate
- **Database**: PostgreSQL 16 (production) / H2 (local dev)
- **Build**: Maven 3.9.6
- **Runtime**: Eclipse Temurin JRE 21
- **Container**: Docker (multi-stage build)

### Database (Render Managed)
- **Engine**: PostgreSQL 16
- **User**: college_admin
- **Database**: college_connect
- **Connection**: JDBC via Spring Data JPA

### Shared/Generated (Monorepo)
- **API Contract**: OpenAPI 3.1 YAML
- **Codegen Tool**: Orval
- **Client Package**: @workspace/api-client-react (React Query hooks)
- **Schema Package**: @workspace/api-zod (runtime validation)

## 3. Monorepo Structure

```
CampusGuard/
├── frontend/                        # React app + UI libraries
│   ├── src/
│   │   ├── main.tsx                 # React bootstrap, API config
│   │   ├── App.tsx                  # Routing & providers
│   │   ├── pages/                   # Route pages (feed, report, admin, etc.)
│   │   ├── components/              # Reusable React components
│   │   ├── hooks/                   # Custom hooks (auth, data fetching)
│   │   └── lib/                     # Utility functions
│   ├── lib/                         # Workspace packages (frontend-facing)
│   │   ├── api-client-react/        # Generated React Query hooks
│   │   ├── api-zod/                 # Generated Zod schemas
│   │   └── integrations-openai-ai-react/  # React AI hooks
│   ├── vite.config.ts               # Build config + dev proxy
│   ├── package.json
│   └── vercel.json                  # Vercel deployment config
│
├── backend/                         # Spring Boot API
│   ├── src/main/java/com/collegeconnect/backend/
│   │   ├── CollegeConnectApplication.java   # Entry point
│   │   ├── controller/              # REST endpoints
│   │   ├── model/                   # JPA @Entity classes
│   │   ├── repository/              # Spring Data JPA interfaces
│   │   ├── dto/                     # Request/response DTOs
│   │   ├── security/                # JWT, auth filters
│   │   └── config/                  # SecurityConfig, CORS
│   ├── src/main/resources/
│   │   └── application.yml          # Spring configuration + env vars
│   ├── lib/                         # Workspace packages (backend-facing)
│   │   ├── api-spec/                # OpenAPI YAML + Orval config
│   │   ├── db/                      # Drizzle schema definitions
│   │   ├── integrations-openai-ai-server/  # OpenAI SDK wrapper
│   │   └── integrations/            # Integration utilities
│   ├── pom.xml                      # Maven build config
│   ├── Dockerfile                   # Multi-stage Docker build
│   ├── .env.example                 # Env var template
│   └── RENDER_DEPLOY.md             # Render deployment guide
│
├── docker/                          # Docker Compose setup
│   ├── docker-compose.yml           # PostgreSQL + backend + frontend services
│   ├── Dockerfile.frontend          # Frontend Docker build
│   ├── nginx.conf                   # Nginx SPA routing config
│   ├── .env.example                 # Docker env template
│   └── LOCAL_DEVELOPMENT_DOCKER.md  # Local dev with Docker guide
│
├── scripts/                         # Utility scripts workspace
│
├── docs/                            # Documentation folder
│
├── package.json                     # Root workspace scripts
├── pnpm-workspace.yaml              # Workspace & package definitions
├── render.yaml                      # Render deployment manifest
├── tsconfig.base.json               # Root TypeScript config
├── .gitignore                       # Git exclusions
└── README.md                        # Main entry point
```

## 4. Authentication Flow

### Registration/Login

```
Frontend (login.tsx)
  ↓
User enters email + password
  ↓
useLoginUser({ email, password })
  ↓ customFetch POST /api/auth/login
Backend (AuthController.loginUser())
  ↓
Validate email format (college domain check)
  ↓
Hash password with BCrypt
  ↓
Query users table
  ↓
Generate JWT with userId as subject, 1-day expiry
  ↓ Response: { token: "jwt...", user: {...} }
  ↓ (Also sets httpOnly cookie for same-origin scenarios)
Frontend
  ↓
localStorage.setItem("jwt_token", response.token)
  ↓
invalidateQueries(["getCurrentUser"])
  ↓
Redirect to /feed
```

### Protected Request

```
Frontend calls protected endpoint (e.g., useListItems())
  ↓
customFetch injects Authorization header
  ↓
if (token in localStorage) {
  headers: { Authorization: "Bearer " + token }
}
  ↓ Request to backend
Backend (JwtAuthenticationFilter)
  ↓
Extract JWT from Authorization header (or cookie)
  ↓ JwtTokenProvider.validateToken(jwt)
  ↓
Extract userId from JWT subject
  ↓
Set SecurityContext with userId + roles
  ↓
Controller receives authenticated request
  ↓ @PreAuthorize enforces role checks
  ↓
Return response
```

### Token Lifecycle

- **Issued**: On login/register
- **Stored**: localStorage (cross-origin) + httpOnly cookie (same-origin)
- **Expiry**: 1 day (86400000 ms, configurable)
- **Refresh**: On every new login request
- **Revocation**: Delete from localStorage (frontend) or invalidate on backend (future enhancement)

## 5. API Communication Pattern

### OpenAPI → Code Generation → Usage

```
1. Source of Truth: lib/api-spec/openapi.yaml
   ├── Defines all endpoints
   ├── Request/response schemas
   └── Auth requirements

2. Generator: Orval (orval.config.ts)
   ├── Reads OpenAPI spec
   ├── Generates React Query hooks → lib/api-client-react/src/generated/
   └── Generates Zod schemas → lib/api-zod/src/generated/

3. Frontend Usage:
   ├── import { useListItems } from "@workspace/api-client-react"
   ├── const { data, isLoading } = useListItems()
   └── Zod schemas validate responses at runtime
```

### Request Flow

```
Frontend Component
  ↓
Call generated hook: useListItems({ page: 1 })
  ↓
React Query calls customFetch mutator
  ↓
customFetch:
  1. Prepend VITE_API_URL if set (production)
  2. Inject Authorization: Bearer token
  3. Serialize body as JSON
  4. Add Content-Type: application/json
  ↓
POST /api/items (or absolute URL in prod)
  ↓
Backend receives + validates + processes
  ↓
Response (200, 400, 401, 500, etc.)
  ↓
customFetch:
  1. Parse response JSON
  2. Validate with Zod schema
  3. Handle errors (throw, retry, etc.)
  ↓
React Query caches result
  ↓
Component re-renders with data
```

## 6. Business Logic Flows

### Item Reporting → Feed Display

```
User submits form: { type: "lost", title, description, category, location, image }
  ↓
Image upload: base64 → POST /api/items/upload-image → returns imageUrl
  ↓
Item creation: POST /api/items { ...data, imageUrl, reportedBy: currentUser.id }
  ↓
Backend validates, creates Item entity, saves to DB
  ↓
Return ItemResponse (with claimCount = 0)
  ↓
Frontend navigates to /feed
  ↓
useListItems() fetches paginated items
  ↓
Each item shows: title, image, category, claimCount, "Claim" button
```

### Claim → OTP Verification → Return

```
User clicks "Claim" on item
  ↓
POST /api/claims { itemId, message }
  ↓
Backend:
  1. Prevent self-claims
  2. Generate 6-digit OTP
  3. Save Claim(status=pending, otp, flagged=false)
  4. Return ClaimResponse (OTP shown only to item reporter)
  ↓
Frontend: Redirect to /claim/:id
  ↓
Claimer sends messages: POST /api/claims/{id}/messages
  ↓
Item reporter receives OTP via message
  ↓
When ready, reporter: POST /api/claims/{id}/verify { otp: "123456" }
  ↓
Backend validates OTP, updates Claim(status=verified), Item(status=claimed)
  ↓
Frontend: Item moves from /feed to /activity
```

### Admin Dashboard Flow

```
Admin user accesses /admin
  ↓
Frontend checks: user.isAdmin === true (or route guards redirect)
  ↓
useAdminGetStats() → GET /api/admin/stats
  ↓
Backend @PreAuthorize("hasRole('ADMIN')") validates
  ↓
Returns: { itemCount, claimCount, userCount, by status/type }
  ↓
useAdminListItems() → GET /api/admin/items?page=1&size=20
  ↓
Returns paginated list with reporter info
  ↓
Admin can:
  - Delete item: DELETE /api/admin/items/{id}
  - Flag claim: POST /api/admin/claims/{id}/flag
  - View transactions: GET /api/admin/transactions
```

## 7. Data Model (Database Schema)

### Users
```
id (UUID)
email (varchar, unique) — college domain validation
passwordHash (varchar) — BCrypt
role (enum: USER, ADMIN)
isAdmin (boolean) — shortcut for role checks
isVerified (boolean)
createdAt (timestamp)
```

### Items
```
id (UUID)
type (enum: lost, found)
title (varchar)
description (text)
category (varchar)
location (varchar)
imageUrl (varchar, nullable)
status (enum: active, claimed, returned)
reportedBy (UUID, FK → users.id)
createdAt (timestamp)
claimCount (calculated or denormalized)
```

### Claims
```
id (UUID)
itemId (UUID, FK → items.id)
claimerId (UUID, FK → users.id)
message (text)
otp (varchar, nullable) — 6-digit code
status (enum: pending, verified, rejected, accepted)
flagged (boolean)
createdAt (timestamp)
verifiedAt (timestamp, nullable)
```

### Messages (Claim Chat)
```
id (UUID)
claimId (UUID, FK → claims.id)
senderId (UUID, FK → users.id)
content (text)
createdAt (timestamp)
```

### Conversations (Admin Chat)
```
id (UUID)
userId (UUID, FK → users.id)
title (varchar)
createdAt (timestamp)
```

### Messages (Chat)
```
id (UUID)
conversationId (UUID, FK → conversations.id)
role (enum: user, assistant)
content (text)
createdAt (timestamp)
```

### OTPs
```
email (varchar, PK)
code (varchar) — 6-digit code
type (enum: registration, login)
used (boolean)
expiresAt (timestamp)
```

## 8. Security Architecture

### Transport Security
- **Protocol**: HTTPS only (enforced by Render, Vercel)
- **Certificates**: Auto-managed by Vercel, Render (Let's Encrypt)
- **Ciphers**: TLS 1.2+ (platform defaults)

### Authentication
- **Method**: JWT (JSON Web Tokens)
- **Signing**: HS256 (HMAC SHA-256) with `JWT_SECRET`
- **Storage**: localStorage (cross-origin) + httpOnly cookie (same-origin)
- **Expiry**: 1 day (configurable)
- **Refresh**: Not implemented yet (future enhancement)

### Authorization
- **Mechanism**: Spring Security `@PreAuthorize` with role checks
- **Roles**: USER (default), ADMIN
- **Protected Routes**: Everything except `/api/auth/*`, `/api/health`
- **Admin Routes**: `/api/admin/*` requires `hasRole('ADMIN')`

### CORS
- **Policy**: Whitelist origins on backend
- **Local Dev**: `localhost:5173,localhost:3000`
- **Production**: `*` (cross-origin required for Vercel→Render)
- **Credentials**: Enabled for cookie-based auth fallback
- **Headers**: Custom headers allowed (Authorization, Content-Type)

### Password Security
- **Hashing**: BCrypt (Spring Security default)
- **Salt**: Auto-generated per password
- **Rounds**: 10 (Spring Boot default)

### Input Validation
- **Frontend**: Zod schemas (runtime type checking)
- **Backend**: Jakarta Validation annotations on DTOs
- **Email**: College domain regex validation

### Secrets Management
- **JWT_SECRET**: Generated by Render on deployment
- **DATABASE_PASSWORD**: Managed by Render (generated)
- **Never`: Committed to git via .gitignore

## 9. Deployment Targets

### Frontend (Vercel)
- **Hosting**: Vercel CDN (edge locations globally)
- **Build**: `pnpm install && pnpm run build --filter @workspace/lost-and-found`
- **Output**: `frontend/dist/public/` (static files)
- **Server**: Nginx (SPA routing + caching)
- **Domain**: www.yourapp.com (or custom domain)
- **HTTPS**: Auto-managed, enforced

### Backend (Render)
- **Hosting**: Render container (free tier: sleeps after 15 min inactivity)
- **Build**: Docker multi-stage (Maven compile → JRE runtime)
- **Registry**: Render's built-in Docker registry
- **Runtime**: JRE 21 container (on port 8080)
- **Database**: Render managed PostgreSQL
- **Scaling**: Manual or auto (paid tier)

### Database (Render Managed)
- **Engine**: PostgreSQL 16
- **Backups**: Daily snapshots (paid tier)
- **High Availability**: Not available on free tier
- **Connections**: Connection pooling via PgBouncer
- **Performance Insights**: Available (paid tier)

## 10. Monitoring & Logging

### Backend Logs
- **Source**: Spring Boot logging (SLF4J)
- **Format**: Human-readable (configurable)
- **Levels**: INFO (default), DEBUG (local dev), WARN, ERROR
- **Access**: Render dashboard → Logs tab

### Database Logs
- **Source**: PostgreSQL
- **Slow Query Logging**: Not enabled (free tier)
- **Backups**: Auto-managed by Render

### Frontend Analytics (Optional, not yet configured)
- **Candidates**: Vercel Analytics, Google Analytics, Sentry
- **Metrics**: Page load time, error rate, user sessions

## 11. Development Workflow

### Local Development
1. Backend + Database in Docker: `docker-compose -f docker/docker-compose.yml up`
2. Frontend dev server: `cd frontend && pnpm run dev`
3. Vite proxy: `/api/*` → `http://localhost:8080`
4. Hot reload: File changes auto-rebuild React

### Feature Branch Workflow
1. Create feature branch: `git checkout -b feature/xyz`
2. Code changes
3. Push: `git push origin feature/xyz`
4. Create Pull Request on GitHub
5. Vercel auto-deploys preview to `feature-xyz--campus-guard.vercel.app`
6. Test preview deployment
7. Merge to main
8. Production deployment triggers automatically

### Testing
- **Frontend**: Load in Vercel preview (manual for now)
- **Backend**: JUnit tests (to be added)
- **Integration**: End-to-end flows in browser (manual)

## 12. Performance Considerations

### Frontend
- **Bundle Size**: ~150KB gzipped (Vite + React optimizations)
- **Caching**: CSS/JS cached 1 year, index.html checked every request
- **CDN**: Vercel global CDN (automatic)
- **Lazy Loading**: Route-based code splitting via Wouter

### Backend
- **Request Timeout**: 60s (Render default)
- **Connection Pool**: 10 connections (Hibernate default)
- **Database**: Indexes on userId, itemId, claimerId (to be verified)
- **Pagination**: 20 items per page (configurable)

### Database
- **Query Optimization**: Eager loading for N+1 prevention
- **Indexes**: On FK columns and frequently queried fields
- **Backups**: Daily snapshots (Render managed)

## 13. Roadmap & Future Enhancements

### Planned
- [ ] Real AI chat integration (wire OpenAI to ChatController)
- [ ] Email/SMS notifications for OTP and claim updates
- [ ] Audit trail for moderation actions
- [ ] Token refresh strategy (short-lived + refresh tokens)
- [ ] Rate limiting on auth endpoints
- [ ] User search functionality
- [ ] Item filtering/search UI
- [ ] Claim messaging UI enhancements

### Low Priority
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Mobile app (React Native)
- [ ] Advanced analytics dashboard
- [ ] Chat typing indicators

## 14. Support & Troubleshooting

### Slow Frontend
- Check Vercel analytics (page load time)
- Inspect DevTools Network tab for slow requests
- Test backend health: `curl /api/health`

### Backend Errors
- View Render logs: Dashboard → Logs tab
- Check database connection: ensure DATABASE_URL is valid
- Verify JWT_SECRET is set and consistent

### Database Issues
- Check Render PostgreSQL dashboard
- Verify connection string format
- Test connection locally: `psql postgresql://...`

### CORS Errors
- Verify ALLOWED_ORIGINS includes frontend domain
- Test with browser DevTools → Network tab
- Check `Access-Control-Allow-Origin` response header

## 15. Diagrams

### Deployment Architecture

```
GitHub
  ↓ Push to main
  ├→ Vercel (frontend)
  │    ├ Build: pnpm run build
  │    ├ Deploy: frontend/dist/public → CDN
  │    └ Live at: vercel.com
  │
  └→ Render (backend + DB)
       ├ Build: Docker → Maven → JAR
       ├ Deploy: JRE container + PostgreSQL
       └ Live at: onrender.com
```

### Request Path

```
Browser (Vercel) → HTTPS → Backend (Render) → JDBC → PostgreSQL (Render)
          ↓
  1. Frontend (Node env vars set VITE_API_URL)
  2. React component mount, useEffect()
  3. useListItems() → customFetch
  4. Inject token from localStorage
  5. POST /api/items with Authorization header
  6. Spring Security filter validates JWT
  7. ItemController.listItems() runs
  8. JPA query executes
  9. Response marshalled to JSON
  10. Zod schema validates response
  11. React Query caches
  12. Component re-renders
```

For deployment details, see [RENDER_DEPLOY.md](backend/RENDER_DEPLOY.md), [VERCEL_DEPLOY.md](frontend/VERCEL_DEPLOY.md), and [LOCAL_DEVELOPMENT_DOCKER.md](docker/LOCAL_DEVELOPMENT_DOCKER.md).
