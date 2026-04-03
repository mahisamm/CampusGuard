# Deployment Guide

Complete instructions for deploying CampusGuard to production on Vercel + Render.

## Architecture Overview

```
GitHub → Vercel (Frontend)  +  Render (Backend + Database)
         Static React app          Docker + Java 21 + PostgreSQL
         Edge CDN cached            Auto-scaling container
         HTTPS enforced           HTTPS enforced
```

## Pre-Deployment Checklist

- [ ] All tests passing locally
- [ ] No hardcoded URLs (use env vars)
- [ ] No secrets in code (use `.env.example`)
- [ ] Git repository is clean (`git status` shows no changes)
- [ ] Feature branch merged to `main`
- [ ] Docker images build successfully locally
- [ ] Frontend build succeeds: `pnpm run build`

## Phase 1: Prepare Repository

### 1.1 Verify Credentials

Ensure no secrets are committed:

```bash
git log -S "password" --all           # Check for password in history
git log -S "client_secret" --all      # Check for OAuth secrets
git log -S "PRIVATE KEY" --all        # Check for keys
```

If secrets found:
1. Remove from code
2. Commit reset: `git commit --amend`
3. Push: `git push origin main --force-with-lease` (use cautiously)

### 1.2 Verify Environment Files

```bash
# Check .gitignore includes env files
cat .gitignore | grep "\.env"

# Verify no .env in git history
git ls-files | grep "\.env"
```

### 1.3 Run Final Tests Locally

```bash
# Backend build
cd backend
mvn clean package -DskipTests

# Frontend build
cd frontend
pnpm run build

# Verify no build warnings/errors
```

## Phase 2: Render Deployment (Backend + Database)

### 2.1 Create Render Account

1. Visit [render.com](https://render.com)
2. Sign up with GitHub account (easier for deployments)

### 2.2 Connect GitHub Repository

1. Dashboard → Settings → Connected Services
2. Click "Connect GitHub"
3. Authorize Render access to your repositories
4. Select CampusGuard repository

### 2.3 Deploy via render.yaml

`render.yaml` defines three services: database, backend, frontend. Render reads it on push.

```bash
# Push to GitHub (triggers Render deployment)
git push origin main
```

Render detects `render.yaml` and creates:
1. `college-connect-db` (PostgreSQL)
2. `college-connect-api` (Docker backend)
3. `college-connect-ui` (static frontend)

### 2.4 Monitor Render Build

1. Dashboard → college-connect-api → Logs
2. Watch for:
   - `Building Docker image...` (5-10 min)
   - `Deploying Docker image...`
   - `Service is live` (green)

3. Verify database is ready:
   - Dashboard → college-connect-db → Logs
   - Should show `database system is ready to accept connections`

### 2.5 Verify Backend is Live

```bash
# Should return HTTP 200
curl https://college-connect-api-xxxx.onrender.com/api/health

# Should return JSON
curl https://college-connect-api-xxxx.onrender.com/api/items
```

### 2.6 Set JWT_SECRET (Optional)

By default, Render auto-generates JWT_SECRET. To use a custom value:

1. Dashboard → college-connect-api → Settings
2. Environment → college-connect-api
3. Add/Edit `JWT_SECRET` with custom value
4. Redeploy: top-right "Deploy" button

## Phase 3: Vercel Deployment (Frontend)

### 3.1 Create Vercel Account

1. Visit [vercel.com](https://vercel.com/)
2. Sign up with GitHub account

### 3.2 Import CampusGuard Repository

1. Dashboard → Add New → Project
2. Select CampusGuard repository
3. Configure:
   - **Framework**: Other (Vite)
   - **Root Directory**: `frontend`
   - **Build Command**: `pnpm install && pnpm run build --filter @workspace/lost-and-found`
   - **Output Directory**: `frontend/dist/public`
   - **Install Command**: `pnpm install --frozen-lockfile`

4. Click **Deploy**

### 3.3 Set Environment Variables

1. Dashboard → Settings → Environment Variables
2. Add:
   - **Name**: `VITE_API_URL`
   - **Value**: Get from Render dashboard → college-connect-api → URL (e.g., `https://college-connect-api-xxxx.onrender.com`)
   - **Environments**: Production, Preview, Development

3. Click **Save** and **Redeploy**

### 3.4 Monitor Vercel Build

1. Dashboard → Deployments
2. Watch for:
   - `Building...`
   - `Ready` (green)

3. Click deployment to view build logs

### 3.5 Verify Frontend is Live

```bash
# Visit your Vercel URL
https://your-project.vercel.app

# Should show CampusGuard login page
```

## Phase 4: Post-Deployment Verification

### 4.1 Test End-to-End Flow

1. **Frontend**: Visit `https://your-project.vercel.app`
2. **Register**: Create new account with college email
3. **Verify**: Check that registration succeeds (user in database)
4. **Login**: Log in with credentials just created
5. **Report Item**: "Report Lost/Found" → fill form → submit
6. **Feed**: Navigate to feed, verify item appears
7. **Claim**: Claim the item, verify OTP flow
8. **Check Backend Logs**: Render dashboard → Logs → verify requests logged

### 4.2 Test Auth Token Persistence

1. Browser F12 → Application → Local Storage
2. Verify `jwt_token` key exists after login
3. Refresh page → should remain logged in
4. Clear localStorage, refresh → should redirect to login

### 4.3 Check CORS Headers

In browser DevTools → Network → click API request:

```
Response Headers:
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
```

### 4.4 Verify Database Persistence

1. Create item via frontend
2. Check in PostgreSQL:
   ```bash
   # Via Render dashboard or SSH
   SELECT * FROM items;
   ```
3. Item should appear in database

### 4.5 Load Testing (Optional)

Use Apache Bench or similar:

```bash
ab -n 100 -c 10 https://college-connect-api-xxxx.onrender.com/api/health
```

Expected: No errors, response time < 1s

## Phase 5: Domain & SSL Setup

### 5.1 Add Custom Domain (Vercel)

1. Vercel Dashboard → Settings → Domains
2. Click **Add** and enter your domain (e.g., `app.yourdomain.com`)
3. Follow DNS setup:
   - Add CNAME record to your DNS provider
   - Currently points to `cname.vercel.app`
4. Wait for DNS propagation (5-30 minutes)

### 5.2 Add Custom Domain (Render)

1. Render Dashboard → college-connect-api → Settings → Render DNS
2. Add your domain (e.g., `api.yourdomain.com`)
3. Add A record to your DNS provider pointing to Render IP
4. Verify DNS: `dig api.yourdomain.com`

### 5.3 Update CORS on Backend

Once domains are live, tighten CORS:

1. Render Dashboard → college-connect-api → Environment
2. Edit `ALLOWED_ORIGINS`:
   ```
   https://app.yourdomain.com,https://www.yourdomain.com,https://api.yourdomain.com
   ```
3. Redeploy

### 5.4 SSL/TLS Certificate

- **Vercel**: Auto-managed by Let's Encrypt, auto-renewed
- **Render**: Same, auto-managed

Verify: Visit `https://app.yourdomain.com` → lock icon in address bar

## Phase 6: Monitoring & Maintenance

### 6.1 Set Up Alerts (Optional)

**Vercel:**
1. Dashboard → Settings → Notifications
2. Enter email for deployment notifications

**Render:**
1. Dashboard → Settings → Notifications
2. Slack integration (recommended)

### 6.2 Monitor Logs

**Backend Logs:**
```bash
# View real-time logs
Render Dashboard → college-connect-api → Logs (refresh for live tail)

# Search logs
Filter by error level, date range
```

**Database Logs:**
```bash
# Via Render dashboard → college-connect-db → Logs
```

### 6.3 Monitor Metrics

**Render:**
- CPU usage
- Memory usage
- Request count
- Response time

View: Render Dashboard → college-connect-api → Metrics

**Vercel:**
- Page load time
- Error rate
- Build times

View: Vercel Dashboard → Analytics

### 6.4 Database Backups

**Free Tier:**
- Daily snapshots (7-day retention)
- Not configurable

**Paid Tier:**
- Custom retention policy
- Point-in-time restore

View backups: Render Dashboard → college-connect-db → Data

### 6.5 Cold Starts

**Free Tier Issue:**
- Backend sleeps after 15 minutes inactivity
- First request takes ~30 seconds (wake-up time)

**Solution:**
- Pin/upgrade to paid tier
- Or accept cold starts

Mitigate: Add "keep-alive" ping (separate tool)

## Phase 7: Troubleshooting Deployment Issues

### Frontend Build Fails

**Issue**: `pnpm: command not found`

**Solution**:
1. Vercel Settings → Build & Development Settings
2. Set **Package Manager** to `pnpm`
3. Redeploy

### Backend Build Fails

**Issue**: `Maven compilation error: Cannot find symbol`

**Solution**:
1. Check Java version: Should be 21
2. Verify all imports are correct
3. Run locally: `mvn clean compile`

### API Calls return 502 or timeout

**Issue**: Backend container is cold/sleeping

**Solution**:
1. First request wakes up container (~30s)
2. Wait, then retry
3. For frequent use, upgrade to paid tier

### CORS Errors

**Issue**: `Access-Control-Allow-Origin` mismatch

**Solution**:
1. Verify `ALLOWED_ORIGINS` on backend includes frontend domain
2. Update: Render → college-connect-api → Environment
3. Redeploy backend

### JWT Token Invalid

**Issue**: Tokens issued before deployment are invalid after backend redeploy

**Solution**:
1. Expected if `JWT_SECRET` changes
2. Users must log in again
3. To preserve token: set fixed `JWT_SECRET` (not auto-generated)

### Database Connection Refused

**Issue**: `JDBC Connection failed`

**Solution**:
1. Verify DATABASE_URL is correct: `postgresql://...`
2. Check DATABASE_USERNAME and PASSWORD
3. Ensure database service is running (Render Dashboard)
4. Test connection: `psql postgresql://...`

### Frontend shows blank page

**Issue**: React mounts but no content

**Solution**:
1. Browser F12 → Console: any JavaScript errors?
2. Network tab: check if API calls are failing
3. Inspect HTML: should have `<div id="root">` with content
4. Check Vercel build logs for errors

## Phase 8: Rollback & Recovery

### Rollback to Previous Version

**Frontend (Vercel):**
1. Dashboard → Deployments
2. Find previous deployment (marked "Stable")
3. Click → menu → Promote to Production

**Backend (Render):**
1. Dashboard → college-connect-api → Deployments
2. Click previous deployment → "Restart"

### Restore Database

**Option 1: Render Backup**
1. Dashboard → college-connect-db → Data
2. Select backup snapshot
3. Click "Restore"

**Option 2: Manual Rollback**
1. Note: Free tier has daily snapshots, restore to yesterday's state
2. Contact Render support for manual recovery

## Phase 9: Continuous Deployment

### Auto-Deploy on Push

Already configured via `render.yaml` and Vercel integration:

1. Push to `main` → Render detects → builds → deploys
2. PR created → Vercel creates preview deployment (auto-deleted on merge)

### Disable Auto-Deploy (if needed)

**Vercel:**
1. Settings → Git
2. Uncheck "Deploy on push"

**Render:**
1. Settings → Auto-deploy
2. Uncheck

### Manual Deploy

**Frontend:**
- Vercel Dashboard → Deployments → "Redeploy"

**Backend:**
- Render Dashboard → college-connect-api → "Manual Deploy" (top-right)

## Phase 10: Production Checklist (Final)

- [ ] Frontend loads without errors
- [ ] Backend API responds to health checks
- [ ] Database has tables created
- [ ] Auth (register/login) works end-to-end
- [ ] Can create items and view in feed
- [ ] Claim workflow works (create → claim → verify)
- [ ] Admin can access admin panel
- [ ] Custom domain(s) are configured and working
- [ ] SSL cert is valid (green lock)
- [ ] Logs are being captured and accessible
- [ ] No hardcoded localhost URLs in code
- [ ] No secrets in environment (use .env.example template)
- [ ] Backups are configured (Render)
- [ ] Monitoring alerts are set up
- [ ] Team has access to dashboards

## Deployment Architecture Diagram

```
Developer
  ↓ git push main
  ↓
GitHub Repository
  ├→ Vercel Webhook
  │    ├ Clone repo
  │    ├ pnpm install
  │    ├ pnpm run build --filter @workspace/lost-and-found
  │    ├ Deploy to global CDN
  │    └ Live at vercel.app
  │
  └→ Render Webhook
       ├ Clone repo
       ├ Read render.yaml
       ├ Build Docker image (Maven → JAR → JRE)
       ├ Store in registry
       ├ Start 3 services:
       │  1. PostgreSQL database
       │  2. Spring Boot backend container
       │  3. Static frontend (optional)
       └ Live at onrender.com
```

## Emergency Contacts

- **Vercel Support**: vercel.com/support
- **Render Support**: render.com/support
- **GitHub Status**: status.github.com

## Next Steps

- Set up monitoring & alerts
- Configure error tracking (Sentry, etc.)
- Plan auto-scaling strategy (if budget allows)
- Document runbook for incident response
- Train team on deployment process

For troubleshooting specific services:
- Backend: [backend/RENDER_DEPLOY.md](../backend/RENDER_DEPLOY.md)
- Frontend: [frontend/VERCEL_DEPLOY.md](../frontend/VERCEL_DEPLOY.md)
- Local dev: [docker/LOCAL_DEVELOPMENT_DOCKER.md](../docker/LOCAL_DEVELOPMENT_DOCKER.md)
