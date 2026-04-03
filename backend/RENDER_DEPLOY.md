# Backend Deployment on Render

This guide explains how to deploy the CampusGuard backend API to Render.

## Prerequisites

- Render.com account
- GitHub repository connected to Render
- `render.yaml` in repository root (already configured)

## Architecture Overview

The deployment consists of three services defined in `render.yaml`:

1. **college-connect-db** — PostgreSQL database
2. **college-connect-api** — Java/Spring Boot backend (Dockerized)
3. **college-connect-ui** — React frontend (static site)

This guide focuses on the backend API service.

## Backend Service Configuration (render.yaml)

The backend is defined in `render.yaml` as:

```yaml
- type: web
  name: college-connect-api
  runtime: docker
  rootDir: backend
  plan: free
  envVars:
    - key: DATABASE_URL
      fromDatabase:
        name: college-connect-db
        property: connectionString
    - key: DATABASE_USERNAME
      fromDatabase:
        name: college-connect-db
        property: user
    - key: DATABASE_PASSWORD
      fromDatabase:
        name: college-connect-db
        property: password
    - key: DATABASE_DRIVER
      value: org.postgresql.Driver
    - key: HIBERNATE_DIALECT
      value: org.hibernate.dialect.PostgreSQLDialect
    - key: JWT_SECRET
      generateValue: true
    - key: ALLOWED_ORIGINS
      value: "*"
```

## Key Backend Environment Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `PORT` | Spring Boot default | Server port (8080) |
| `DATABASE_URL` | Render PostgreSQL service | JDBC connection string |
| `DATABASE_USERNAME` | Render PostgreSQL service | DB user |
| `DATABASE_PASSWORD` | Render PostgreSQL service | DB password |
| `DATABASE_DRIVER` | render.yaml | PostgreSQL driver class |
| `HIBERNATE_DIALECT` | render.yaml | Hibernate dialect for PostgreSQL |
| `JWT_SECRET` | Render (auto-generated) | Token signing key |
| `ALLOWED_ORIGINS` | render.yaml | CORS: `*` allows cross-origin frontend calls |

## Deployment Steps

### Step 1: Connect GitHub Repository to Render

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **New** → **Web Service**
3. Select **Deploy an existing repository** (or connect your GitHub account)
4. Choose the CampusGuard repository
5. Click **Connect**

### Step 2: Deploy Using render.yaml

1. On the Web Service creation page:
   - **Name**: `college-connect-api` (or your preferred name)
   - **Environment**: `Docker`
   - **Region**: Choose region closest to users (e.g., `us-east-1`)
   - **Branch**: `main` (or your default branch)

2. Scroll down to **Advanced**:
   - **Build Command**: Leave empty (Dockerfile handles this)
   - **Start Command**: Leave empty (Dockerfile ENTRYPOINT handles this)

3. Render will auto-detect `render.yaml` and deploy all three services (DB, API, UI)

### Step 3: Monitor Deployment

1. Render dashboard shows build progress
2. Watch logs for:
   - Maven build success
   - Docker image creation
   - Spring Boot startup messages
   - Database connection establishment

### Step 4: Verify Deployment

Once deployed, test the backend health:

```bash
curl https://college-connect-api-xxxx.onrender.com/api/health
```

Expected response:
```json
{
  "status": "UP"
}
```

### Step 5: Configure Frontend API URL

Frontend needs to know the backend URL. In `render.yaml`, frontend receives:

```yaml
envVars:
  - key: VITE_API_URL
    fromService:
      type: web
      name: college-connect-api
      property: hostWithScheme
```

This injects the full HTTPS URL (e.g., `https://college-connect-api-xxxx.onrender.com`) into the frontend build.

## Database Initialization

On first deployment:

1. Render creates PostgreSQL database (`college-connect-db`)
2. Spring Boot's `spring.jpa.hibernate.ddl-auto: update` auto-creates tables
3. No manual schema migration needed

To reset database:
1. Go to Render dashboard
2. Select `college-connect-db` service
3. Click **Data** tab
4. Delete the database (warns of data loss)
5. Redeploy backend to trigger schema creation

## JWT Secret Management

- **Locally**: `application.yml` has a dev default (not secure for real use)
- **Render**: `generateValue: true` creates a random secret per deployment
- **Considerations**:
  - Each time you redeploy, JWT secret changes (all issued tokens become invalid)
  - For persistent tokens across deployments, set `JWT_SECRET` to a fixed value in Render dashboard instead of `generateValue: true`

## CORS Configuration

Current production setting:

```yaml
ALLOWED_ORIGINS: "*"
```

This allows the frontend (deployed anywhere) to call the backend.

**For tighter security**, replace `*` with specific frontend domains:

```yaml
ALLOWED_ORIGINS: "https://your-app.vercel.app,https://www.your-app.vercel.app"
```

Update in `render.yaml`:

```yaml
- key: ALLOWED_ORIGINS
  value: "https://your-app.vercel.app"
```

Then redeploy.

## Logging & Monitoring

### View Logs

1. Render dashboard → college-connect-api service
2. Click **Logs** tab (real-time tail)
3. Logs show Spring Boot startup, requests, errors

### Structured Logging

Current backend uses Spring Boot defaults. To enable JSON logs for better monitoring:

1. Add `spring.jackson.default-property-inclusion: non_null` to `application.yml`
2. Configure JSON logging via logback config (optional)

## Troubleshooting

### Build Fails: Maven Errors

**Issue**: Docker build step fails on Maven compile

**Solution**:
1. Check Java version: Should be Java 21 (pom.xml specifies `21`)
2. Ensure all dependencies in `pom.xml` are available (check Maven Central)
3. Review build logs for specific missing classes or syntax errors

### Database Connection Fails

**Issue**: Spring Boot can't connect to PostgreSQL

**Solution**:
1. Verify DATABASE_URL format: `postgresql://user:password@host:5432/dbname`
2. Check DATABASE_USERNAME and DATABASE_PASSWORD are set
3. Ensure DATABASE_DRIVER = `org.postgresql.Driver`
4. Ensure HIBERNATE_DIALECT = `org.hibernate.dialect.PostgreSQLDialect`
5. Wait 30 seconds after database service starts before backend boots (race condition)

### CORS Errors in Frontend

**Issue**: Frontend requests blocked by CORS policy

**Solution**:
1. Verify ALLOWED_ORIGINS includes frontend origin
2. For cross-origin Render deployments, set to `*` (current setting)
3. Test manually:
   ```bash
   curl -H "Origin: https://your-frontend.vercel.app" \
        -H "Access-Control-Request-Method: POST" \
        https://college-connect-api.onrender.com/api/items
   ```

### Health Check Endpoint Unreachable

**Issue**: `/api/health` returns 502 or times out

**Solution**:
1. Verify service is running: check Render logs
2. Check PORT env var (should be 8080)
3. Test locally first: `mvn clean package && java -jar target/*.jar`
4. Review Spring Boot initialization logs

## Local Testing Before Deployment

Before pushing to Render, test locally:

```bash
# Terminal 1: PostgreSQL (or use H2 defaults)
cd backend

# Set PostgreSQL connection if testing with real DB
export DATABASE_URL=postgresql://user:pass@localhost:5432/college_connect
export DATABASE_USERNAME=user
export DATABASE_PASSWORD=pass

# Build and run
mvn clean package -DskipTests
java -jar target/*.jar

# Terminal 2: Test endpoint
curl http://localhost:8080/api/health
```

# Production Checklist

Before going live:

- [ ] JWT_SECRET is a secure random string (not the dev default)
- [ ] DATABASE_DRIVER and HIBERNATE_DIALECT are PostgreSQL-specific
- [ ] ALLOWED_ORIGINS is restricted to expected frontend domains
- [ ] `/api/health` endpoint responds 200 OK
- [ ] Frontend can reach backend API over HTTPS
- [ ] Auth endpoints (`/api/auth/login`, etc.) work end-to-end
- [ ] Database tables exist and are queryable
- [ ] Logs are being captured and monitorable
- [ ] Error responses are properly formatted

## Deployment Diagram

```
GitHub Repository
    ↓
Render detects render.yaml
    ↓
Creates 3 services:
  1. college-connect-db (PostgreSQL)
  2. college-connect-api (Docker + Spring Boot)
  3. college-connect-ui (Node + React static)
    ↓
Backend builds via Dockerfile
  - Maven compile
  - Docker image creation
  - JRE runtime container
    ↓
Backend starts
  - Connects to PostgreSQL
  - Creates tables via Hibernate
  - Starts on PORT 8080
  - Listens for API requests
    ↓
Frontend receives VITE_API_URL
    ↓
Frontend calls HTTPS backend endpoint
```

## Next Steps

- Move to Phase 4: Database PostgreSQL configuration (migrations, seeds)
- Move to Phase 5: Frontend deployment on Vercel
- Move to Phase 6: Docker Compose for local development

For more details, see [Render Web Services Documentation](https://render.com/docs/web-services).
