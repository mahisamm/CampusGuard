# Local Development Guide

Complete setup and workflow guide for developing CampusGuard locally.

## Quick Start (5 minutes)

### Prerequisites
- Node.js 20+ 
- Java 21
- Maven 3.9+ (or use bundled Maven)
- Docker Desktop (optional, for PostgreSQL)
- Git

### Option A: Backend + PostgreSQL in Docker, Frontend local (Recommended)

```bash
# Terminal 1: Start backend + database
cd docker
docker-compose up

# Wait for services to be healthy (~30 seconds)
# You should see: "backend is healthy" in logs

# Terminal 2: Start frontend dev server
cd frontend
pnpm run dev

# Access: http://localhost:5173
```

### Option B: All Local (requires PostgreSQL)

```bash
# Terminal 1: Start PostgreSQL (must be running manually or via Docker)
docker run --rm -p 5432:5432 \
  -e POSTGRES_USER=college_admin \
  -e POSTGRES_PASSWORD=college_password \
  -e POSTGRES_DB=college_connect \
  postgres:16-alpine

# Terminal 2: Start backend
cd backend
export DATABASE_URL=postgresql://college_admin:college_password@localhost:5432/college_connect
mvn clean package -DskipTests
java -jar target/*.jar

# Terminal 3: Start frontend
cd frontend
pnpm run dev

# Access: http://localhost:5173
```

### Option C: Everything in Docker

```bash
# Uncomment frontend service in docker/docker-compose.yml

cd docker
docker-compose up --build

# Access: http://localhost:3000 (frontend directly)
```

## Development URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | http://localhost:5173 | React dev server (hot reload) |
| Backend API | http://localhost:8080 | Spring Boot API |
| PostgreSQL | localhost:5432 | Database (Docker) |
| Health Check | http://localhost:8080/api/health | Backend liveness |

## Workspace Commands

From repository root:

```bash
# Install all workspace dependencies
pnpm install

# Type check all packages
pnpm run typecheck

# Build all packages
pnpm run build

# Generate API client from OpenAPI spec
pnpm --filter @workspace/api-spec run codegen
```

## Frontend Development

### Start Dev Server

```bash
cd frontend
pnpm run dev
```

- Runs on port 5173
- Hot reload on file changes
- Vite proxy: `/api` → `http://localhost:8080`
- Open http://localhost:5173

### Common Tasks

```bash
# Type check
cd frontend
pnpm run typecheck

# Build production bundle (test before deployment)
pnpm run build

# Preview production build locally
pnpm run serve

# Format code
pnpm run format  # (if available)
```

### Debugging

**Browser DevTools:**
- Open http://localhost:5173
- F12 → Console for JavaScript errors
- Network tab: inspect API requests
- Application tab: check localStorage for `jwt_token`

**VSCode Debugger:**
- Install "Debugger for Firefox" or "Debugger for Chrome" extension
- F5 to start debugging
- Set breakpoints in src/

**React DevTools:**
- Install "React Developer Tools" browser extension
- Inspect components, props, state

### Making API Calls

Frontend uses generated hooks from `@workspace/api-client-react`:

```typescript
import { useListItems, useCreateItem } from "@workspace/api-client-react";

function MyComponent() {
  // Fetch items
  const { data, isLoading, error } = useListItems({ page: 1 });
  
  // Create item
  const createMutation = useCreateItem();
  
  const handleCreate = () => {
    createMutation.mutate({
      type: "lost",
      title: "My Lost Item",
      description: "...",
      category: "electronics",
      location: "Building A",
      imageUrl: "data:image/...",
    });
  };
  
  return (
    // JSX...
  );
}
```

**Token injection is automatic** via `setAuthTokenGetter` in `main.tsx`.

### Pages & Routes

| Route | File | Purpose |
|-------|------|---------|
| `/` | pages/landing.tsx | Unauthenticated landing |
| `/login` | pages/auth/login.tsx | User login |
| `/register` | pages/auth/register.tsx | User registration |
| `/feed` | pages/feed/index.tsx | Main items feed |
| `/report` | pages/report/index.tsx | Report lost/found item |
| `/item/:id` | pages/item-detail.tsx | Item details + claims |
| `/claim/:id` | pages/claim-verify.tsx | Claim verification |
| `/activity` | pages/activity.tsx | User's claims history |
| `/chat` | pages/chat.tsx | AI support chat |
| `/admin` | pages/admin.tsx | Admin dashboard |

## Backend Development

### Start Backend

```bash
cd backend

# Option 1: Maven (uses bundled Maven)
./apache-maven-3.9.6/bin/mvn clean package -DskipTests
java -jar target/*.jar

# Option 2: Maven (system Maven)
mvn clean package -DskipTests
java -jar target/*.jar

# Option 3: Run without rebuild (if JAR already built)
java -jar target/*.jar
```

**Default config (H2 in-memory database):**
- No setup needed
- Database created on startup
- Data lost on restart

**PostgreSQL config:**
```bash
export DATABASE_URL=postgresql://college_admin:college_password@localhost:5432/college_connect
export DATABASE_USERNAME=college_admin
export DATABASE_PASSWORD=college_password
export DATABASE_DRIVER=org.postgresql.Driver
export HIBERNATE_DIALECT=org.hibernate.dialect.PostgreSQLDialect
java -jar target/*.jar
```

### Common Tasks

```bash
# Build only (no run)
cd backend
mvn clean compile

# Run tests
mvn test

# Build with tests
mvn clean package

# Skip tests for speed
mvn clean package -DskipTests

# View dependency tree
mvn dependency:tree

# Check for security vulnerabilities
mvn org.owasp:dependency-check-maven:check
```

### Code Structure

| Folder | Purpose |
|--------|---------|
| `src/main/java/com/collegeconnect/backend/controller/` | REST endpoints |
| `src/main/java/com/collegeconnect/backend/model/` | JPA entities |
| `src/main/java/com/collegeconnect/backend/repository/` | Data access layer |
| `src/main/java/com/collegeconnect/backend/dto/` | Request/response objects |
| `src/main/java/com/collegeconnect/backend/security/` | JWT, auth filters |
| `src/main/java/com/collegeconnect/backend/config/` | Spring configuration |
| `src/main/resources/application.yml` | Configuration file |

### API Endpoints (for testing)

```bash
# Health check
curl http://localhost:8080/api/health

# List items (no auth required for GET)
curl http://localhost:8080/api/items

# Register user
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "student@college.edu",
    "password": "somepassword",
    "name": "John Doe"
  }'

# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "student@college.edu",
    "password": "somepassword"
  }'

# Response includes JWT token in body (copy for subsequent requests)

# Create item (auth required)
curl -X POST http://localhost:8080/api/items \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "lost",
    "title": "Lost Backpack",
    "description": "Blue backpack with laptop",
    "category": "personal_items",
    "location": "Building A",
    "imageUrl": "data:image/..."
  }'
```

### Debugging

**View Logs:**
- Console shows Spring Boot startup messages
- DEBUG: Set `LOGGING_LEVEL_COM_COLLEGECONNECT=DEBUG`
- Check `application.yml` for `show-sql: true` to see SQL queries

**Database:**
```bash
# Connect to PostgreSQL (if using Docker)
docker exec -it campus-guard-db psql -U college_admin -d college_connect

# List tables
\dt

# Query users
SELECT * FROM users;

# Exit
\q
```

**CORS Issues:**
- Frontend and backend on different ports (both local dev)
- Vite proxy handles it: `/api` → backend
- If calling with absolute URL, check ALLOWED_ORIGINS env var

## Database Management

### Local PostgreSQL (Docker)

```bash
# Start PostgreSQL
docker run -d \
  --name campus-db \
  -p 5432:5432 \
  -e POSTGRES_USER=college_admin \
  -e POSTGRES_PASSWORD=college_password \
  -e POSTGRES_DB=college_connect \
  postgres:16-alpine

# Connect via psql
psql -h localhost -U college_admin -d college_connect

# View tables after running Spring Boot
psql> \dt

# Stop
docker stop campus-db

# Remove
docker rm campus-db
```

### Reset Database

```bash
# Option 1: Delete Docker volume (if using Docker Compose)
docker-compose down -v

# Option 2: Drop and recreate database (manual)
psql -U college_admin -d postgres
# psql> DROP DATABASE college_connect;
# psql> CREATE DATABASE college_connect;
```

### Database Schema

Initially empty. Spring Boot creates tables on first run via Hibernate `ddl-auto: update`.

Tables created (visible after login attempt):
- users
- items
- claims
- messages
- conversations
- otps

## Testing Workflows

### End-to-End: Register → Report → Claim

1. **Frontend**: Visit http://localhost:5173
2. **Register**: Click "Sign Up", fill form, submit
3. **Backend**: Saves user to database
4. **Frontend**: Auto-login, redirect to /feed
5. **Frontend**: "Report Item" → fill form → upload image → submit
6. **Backend**: Creates item, returns response
7. **Frontend**: Item appears in feed
8. **Frontend**: Click "Claim" → submit claim message
9. **Backend**: Generates OTP, saves claim
10. **Frontend**: Redirects to claim verification page
11. **Repeat with another user** to test claim workflow

### Admin Features

1. **Set user as admin** (database SQL or implement admin panel):
   ```sql
   UPDATE users SET is_admin = true WHERE email = 'admin@college.edu';
   ```
2. **Frontend**: Login, navigate to /admin (visible if is_admin=true)
3. **View stats, delete items, flag claims**

## Environment Variables

See [ENV_VARIABLES.md](../docs/ENV_VARIABLES.md) for complete list.

**Local dev defaults:**
- `PORT`: 8080 (backend), 5173 (frontend)
- `DATABASE_URL`: H2 in-memory (backend), uses proxy (frontend)
- `JWT_SECRET`: dev default (not secure, fine for local)
- `ALLOWED_ORIGINS`: localhost:5173, localhost:3000

To override:
```bash
export PORT=9000
export JWT_SECRET=my_custom_secret
node_executable (frontend) or java -jar (backend)
```

## Troubleshooting

### Frontend: "Cannot GET /api/items"

**Cause**: Vite proxy not working or backend not running

**Solution**:
1. Verify backend is running: `curl http://localhost:8080/api/health`
2. Check Vite config `vite.config.ts` proxy setting
3. Restart Vite dev server: `Ctrl+C`, `pnpm run dev`

### Backend: Port 8080 already in use

**Solution**:
```bash
# Kill process using port 8080
lsof -i :8080 | grep LISTEN | awk '{print $2}' | xargs kill -9

# Or use different port
PORT=9000 java -jar target/*.jar
```

### Frontend: "localhost refused to connect"

**Cause**: Frontend dev server not running

**Solution**:
```bash
cd frontend
pnpm run dev
```

### Database connection refused

**Cause**: PostgreSQL not running or wrong credentials

**Solution**:
1. Verify PostgreSQL: `docker ps | grep postgres`
2. Check credentials in docker-compose.yml or backend config
3. Restart: `docker-compose restart postgres`

### JWT token invalid after backend restart

**Cause**: JWT_SECRET changed (only applicable if not using dev default)

**Solution**:
1. Clear localStorage: F12 → Application → Local Storage → Delete `jwt_token`
2. Log in again
3. New token will be generated

### Changes not reflecting in frontend

**Cause**: Vite cache or old bundle

**Solution**:
1. Hard refresh: `Ctrl+Shift+R` (Chrome) or `Cmd+Shift+R` (Mac)
2. Clear browser cache: DevTools → Application → Cache Storage
3. Restart Vite: `Ctrl+C`, `pnpm run dev`

## Git Workflow

```bash
# Start new feature
git checkout -b feature/my-feature

# Make changes
# Test locally

# Commit
git add .
git commit -m "feat: add my feature"

# Push
git push origin feature/my-feature

# Create Pull Request on GitHub
# Vercel will auto-deploy preview

# After review, merge to main
git checkout main
git merge feature/my-feature
git push origin main

# Production deployment triggers automatically
```

## Performance Tips

### Frontend
- Use React Query hooks to cache API responses
- Lazy load components with `React.lazy()`
- Check DevTools Network tab for slow requests
- Test production build locally: `pnpm run build && pnpm run serve`

### Backend
- Enable DEBUG logging only when needed (slows down)
- Check slow queries: `show-sql: true` in application.yml
- Use pagination to avoid loading all items

### Database
- Keep indexes on frequently queried columns
- Analyze query plans: `EXPLAIN ANALYZE SELECT ...;`
- Connection pooling: adjust pool size if bottleneck

## Next Steps

- For deployment: [DEPLOYMENT_GUIDE.md](../docs/DEPLOYMENT_GUIDE.md)
- For architecture: [SYSTEM_ARCHITECTURE.md](../docs/SYSTEM_ARCHITECTURE.md)
- For environment variables: [ENV_VARIABLES.md](../docs/ENV_VARIABLES.md)
