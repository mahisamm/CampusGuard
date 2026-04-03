# Local Development with Docker Compose

This guide explains how to run CampusGuard locally using Docker Compose with PostgreSQL.

## Prerequisites

- Docker Desktop installed (includes Docker and Docker Compose)
- Git repository cloned
- No services running on ports 5432 (PostgreSQL) or 8080 (backend)

## Quick Start

### Option 1: Backend + PostgreSQL Only (Recommended for development)

Frontend runs separately in dev mode for hot reloading.

```bash
# From repository root
docker-compose -f docker/docker-compose.yml up

# In separate terminal, run frontend dev server
cd frontend
pnpm run dev
```

Access:
- Frontend: `http://localhost:5173` (Vite dev server with hot reload)
- Backend API: `http://localhost:8080`
- PostgreSQL: `localhost:5432`

### Option 2: Full Stack (Backend + PostgreSQL + Frontend)

Entire app runs in Docker.

```bash
# 1. Uncomment frontend service in docker-compose.yml
# (edit docker/docker-compose.yml and uncomment the "frontend" service section)

# 2. Build and run all services
docker-compose -f docker/docker-compose.yml up --build

# Access frontend at http://localhost:3000
```

## Docker Compose Architecture

File: `docker/docker-compose.yml`

Services:

1. **postgres** (PostgreSQL 16)
   - Image: `postgres:16-alpine`
   - Port: `5432`
   - User: `college_admin`
   - Password: `college_password`
   - Database: `college_connect`
   - Volume: `postgres-data` (persists between runs)
   - Health check: Verifies PostgreSQL is ready before backend starts

2. **backend** (Spring Boot)
   - Build: Dockerfile from `backend/`
   - Port: `8080`
   - Depends on: postgres (waits for health check)
   - Environment: Injected with PostgreSQL connection details
   - Health check: Calls `/api/health` to verify startup

3. **frontend** (React + Nginx) — Optional, currently commented out
   - Build: `Dockerfile.frontend`
   - Port: `3000`
   - Depends on: backend

Network: `campus-network` (internal bridge for service-to-service communication)

## Running Services

### Start All Services

```bash
cd docker

# Start in foreground (show logs)
docker-compose up

# Start in background (daemon mode)
docker-compose up -d

# Start with full rebuild
docker-compose up --build
```

### Stop Services

```bash
# Stop and remove containers
docker-compose down

# Stop but keep data volume
docker-compose stop

# Remove everything including volumes (destroy data!)
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs -f backend
docker-compose logs -f postgres

# Follow logs (live tail)
docker-compose logs -f
```

### Rebuild Images

```bash
# Rebuild all images
docker-compose build

# Rebuild specific service
docker-compose build backend
```

## Environment Variables

Services use environment variables defined in `docker-compose.yml`:

### Backend Environment (auto-set)

```yaml
DATABASE_URL: jdbc:postgresql://postgres:5432/college_connect
DATABASE_USERNAME: college_admin
DATABASE_PASSWORD: college_password
DATABASE_DRIVER: org.postgresql.Driver
HIBERNATE_DIALECT: org.hibernate.dialect.PostgreSQLDialect
JWT_SECRET: (dev default or from override)
ALLOWED_ORIGINS: http://localhost:5173,http://localhost:3000,http://localhost:80
```

### Override Variables

```bash
# Set JWT_SECRET from command line
JWT_SECRET=my_custom_secret docker-compose up

# Or create a .env file in docker/ directory
# .env format: KEY=value
JWT_SECRET=my_custom_secret
PORT=8080
```

## Data Persistence

PostgreSQL data is stored in Docker volume `postgres-data`.

### Inspect Volume

```bash
docker volume ls
docker volume inspect campusguard_postgres-data
```

### Delete Volume (Destroy All Data)

```bash
docker-compose down -v
```

## Database Management

### Connect to PostgreSQL

```bash
# Using psql (if installed locally)
psql -h localhost -U college_admin -d college_connect

# Or inside Docker
docker exec -it campus-guard-db psql -U college_admin -d college_connect

# List tables
\dt

# Quit
\q
```

### Reset Database

```bash
# Keep containers, reset data
docker-compose down -v
docker-compose up
```

## Troubleshooting

### Backend fails to start: "Address already in use"

**Issue**: Port 8080 is already in use

**Solution**:
```bash
# Find what's using port 8080
lsof -i :8080
# Or on Windows:
netstat -ano | findstr :8080

# Kill process or change port in docker-compose.yml
```

### Backend can't connect to PostgreSQL

**Issue**: Connection timeout or "postgres: unknown host"

**Solution**:
1. Verify postgres service is running: `docker-compose ps`
2. Check health: `docker-compose logs postgres`
3. Ensure postgres has passed health check before backend starts
4. Verify DATABASE_URL in docker-compose.yml uses `postgres` (service name, not localhost)

### PostgreSQL password issues

**Issue**: "password authentication failed"

**Solution**:
1. Verify DATABASE_USERNAME and DATABASE_PASSWORD match docker-compose.yml
2. Reset: `docker-compose down -v && docker-compose up`
3. Database is created with user on first run

### Frontend can't reach backend

**Issue**: Frontend gets CORS error or "cannot reach API"

**Solution**:
1. If running frontend separately on Vite dev server: VITE_API_URL is empty, Vite proxy handles it
2. If running frontend in Docker: Vite proxy won't work, VITE_API_URL should be `http://backend:8080`
3. Verify backend is healthy: `curl http://localhost:8080/api/health`

### Slow builds on first run

**Issue**: Docker build takes 5+ minutes on initial `docker-compose up --build`

**Reason**:
- Maven downloads all dependencies (~1GB)
- Node packages download (~500MB)
- Normal on first run, cached on subsequent builds

**Optimization**:
- Use volume mounts for Maven cache: [see advanced section]

## Advanced: Persistent Build Cache

Speed up rebuilds by caching Maven and npm artifacts:

Edit `docker-compose.yml`:

```yaml
services:
  backend:
    # ... existing config ...
    volumes:
      - maven-cache:/root/.m2  # Cache Maven dependencies
```

At end of file:

```yaml
volumes:
  postgres-data:
    driver: local
  maven-cache:
    driver: local
```

## Frontend Development Workflow

Recommended flow for active development:

```bash
# Terminal 1: Start backend + database
cd docker
docker-compose up

# Terminal 2: Start frontend dev server (hot reload)
cd frontend
pnpm run dev

# Access at http://localhost:5173
```

Benefits:
- Backend runs consistently in Docker
- Frontend hot-reloads on file save
- Easy debugging with browser DevTools
- No need to rebuild for each change

## Production-Like Testing

Test production-like scenario locally:

```bash
# Uncomment frontend service in docker-compose.yml

# Build all images
docker-compose build

# Run all services
docker-compose up

# Access frontend at http://localhost:3000 (via Nginx)
```

This mirrors Vercel (frontend static) + Render (backend API) architecture.

## Cleanup

```bash
# Remove all containers, networks (keep volumes)
docker-compose down

# Full cleanup (remove everything)
docker-compose down -v

# Prune unused Docker resources (frees disk space)
docker system prune -a --volumes
```

## Health Checks

Services include health checks (defined in compose):

### Check Status

```bash
docker-compose ps

# Shows health status for each service
#  postgres is healthy
#  backend is healthy (after becoming ready)
```

### Manual Health Check

```bash
# Backend API
curl http://localhost:8080/api/health

# PostgreSQL (inside container)
docker exec campus-guard-db pg_isready -U college_admin
```

## Next Steps

- **Local dev**: Use Option 1 above (backend Docker + frontend `pnpm run dev`)
- **Full Docker test**: Use Option 2 above (everything in containers)
- **Production**: Deploy frontend to Vercel, backend to Render (see VERCEL_DEPLOY.md and RENDER_DEPLOY.md)

For more Docker Compose reference: [Official Docs](https://docs.docker.com/compose/compose-file/compose-file-v3/)
