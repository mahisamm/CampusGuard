# Frontend Deployment on Vercel

This guide explains how to deploy the CampusGuard frontend React application to Vercel.

## Prerequisites

- Vercel account
- GitHub repository connected to Vercel
- `vercel.json` in frontend directory (already configured)

## Architecture Overview

The frontend is deployed to Vercel as a static React application:

1. Frontend builds React app to static files
2. Vercel hosts the static site with edge caching
3. Frontend calls backend API on Render via HTTPS
4. JWT token stored in localStorage for cross-origin authentication

## Frontend Configuration (vercel.json)

The frontend is configured in `frontend/vercel.json`:

```json
{
  "buildCommand": "pnpm install && pnpm run build --filter @workspace/lost-and-found",
  "outputDirectory": "frontend/dist/public",
  "installCommand": "pnpm install --frozen-lockfile",
  "devCommand": "pnpm run dev --filter @workspace/lost-and-found",
  "env": {
    "VITE_API_URL": {
      "description": "Backend API URL"
    }
  },
  "rewrites": [
    {
      "source": "/:path*",
      "destination": "/index.html"
    }
  ]
}
```

## Key Frontend Environment Variables

| Variable | Purpose | Set Where |
|----------|---------|-----------|
| `VITE_API_URL` | Backend API base URL | Vercel dashboard env vars |

## How API URL is Injected

**Local development:**
- `VITE_API_URL` is empty (left unset)
- Vite proxy forwards `/api/*` to `http://localhost:8080`
- Frontend can call `/api/auth/login` as relative path

**Vercel → Render:**
- `VITE_API_URL` set to backend service HTTPS URL (e.g., `https://college-connect-api-xxxx.onrender.com`)
- Frontend makes absolute requests: `https://college-connect-api-xxxx.onrender.com/api/auth/login`
- CORS allows `*` on backend, so cross-origin requests succeed

**Frontend runtime config:**
See `frontend/src/main.tsx`:

```typescript
if (import.meta.env.VITE_API_URL) {
  setBaseUrl(import.meta.env.VITE_API_URL);
}

setAuthTokenGetter(() => localStorage.getItem("jwt_token"));
```

- If `VITE_API_URL` is set, all API calls prepend it
- JWT token from localStorage is sent in `Authorization: Bearer` header

## Deployment Steps

### Step 1: Connect GitHub Repository to Vercel

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click **Add New** → **Project**
3. Select **Import Git Repository**
4. Choose your GitHub account and repository (CampusGuard)
5. Click **Import**

### Step 2: Configure Project Settings

On the Vercel project import screen:

1. **Framework Preset**: `Other` (or leave blank, Vercel auto-detects Vite)
2. **Root Directory**: `frontend` (important: tell Vercel where the frontend is)
3. **Build Command**: Should auto-detect as `pnpm run build --filter @workspace/lost-and-found`
   - If not, paste: `pnpm install && pnpm run build --filter @workspace/lost-and-found`
4. **Output Directory**: `frontend/dist/public`
5. **Install Command**: `pnpm install --frozen-lockfile`

### Step 3: Set Environment Variables

1. Scroll down to **Environment Variables**
2. Add:
   - **Name**: `VITE_API_URL`
   - **Value**: `https://college-connect-api-xxxx.onrender.com` (your Render backend URL)
   - **Environments**: Select `Production` (and optionally `Preview`, `Development`)
3. Click **Add**

### Step 4: Deploy

1. Click **Deploy**
2. Vercel will build and deploy your frontend
3. Monitor build logs for errors
4. Once deployed, your site is live at `your-project.vercel.app`

### Step 5: Verify Deployment

1. Visit `https://your-project.vercel.app`
2. Test login/register endpoints
3. Verify CORS works (check browser console for CORS errors)
4. Test feed loading, item creation, claims

## Build Process

### Build Command Explained

```bash
pnpm install && pnpm run build --filter @workspace/lost-and-found
```

- `pnpm install`: Install all workspace dependencies
- `--filter @workspace/lost-and-found`: Build only the frontend package
- `pnpm run build`: Execute Vite build (outputs to `frontend/dist/public`)

### Output Directory

Build output is placed in: `frontend/dist/public/`

Vercel uploads this directory to CDN and serves it.

### Build Time

- First build: ~2-3 minutes (download deps, compile TypeScript)
- Subsequent builds: ~1-2 minutes (cache hit on deps)

## Environment-Specific Builds

You can have different backend URLs for different environments:

### Option 1: Vercel Environment Variables

Set `VITE_API_URL` differently per environment in Vercel dashboard:

1. Dashboard → Project → Settings → Environment Variables
2. Add same variable for different environments:
   - `Production`: `https://college-connect-api.onrender.com`
   - `Preview`: `https://staging-api.onrender.com`

### Option 2: .env Files

Create `frontend/.env.production`:

```
VITE_API_URL=https://college-connect-api.onrender.com
```

Vite will automatically use this for production builds.

## Custom Domain Setup

To use a custom domain (e.g., `app.yourdomain.com`):

1. Vercel Dashboard → Project → Settings → Domains
2. Click **Add** and enter your domain
3. Follow DNS setup instructions
4. Usually adds a CNAME record to `cname.vercel.app`

## Redeploys & Git Workflow

Vercel auto-deploys on every push:

1. Push a commit to `main` (or configured branch)
2. Vercel detects and triggers build
3. Build runs, tests, deploys to production
4. Site is live (usually within 2-5 minutes)

To redeploy without code changes:

1. Dashboard → Project → Deployments
2. Click **Redeploy** on any previous deployment

## SPA Routing Setup

CampusGuard uses client-side routing (Wouter). To ensure all routes work:

**vercel.json includes:**

```json
"rewrites": [
  {
    "source": "/:path*",
    "destination": "/index.html"
  }
]
```

This tells Vercel to serve `index.html` for all routes (except existing assets), allowing React Router to handle navigation client-side.

## CORS Configuration

Since frontend and backend are on different domains:

**Frontend**: `https://app.yourdomain.com` (Vercel)
**Backend**: `https://college-connect-api-xxxx.onrender.com` (Render)

Backend CORS setting (`ALLOWED_ORIGINS`):
- Current: `*` (allows any origin)
- For production security, set to: `https://app.yourdomain.com,https://www.app.yourdomain.com`

Update in `render.yaml`:

```yaml
- key: ALLOWED_ORIGINS
  value: "https://app.yourdomain.com"
```

Then redeploy backend.

## Troubleshooting

### Build Fails: "pnpm not found"

**Issue**: Vercel can't find `pnpm` command

**Solution**:
1. Dashboard → Settings → Build & Development Settings
2. Ensure **Package Manager** is set to `pnpm`
3. If not, manually set under **Environment Variables**:
   - Set `npm_config_user_agent=pnpm` (Vercel will use pnpm)

### Build Fails: "filter @workspace/lost-and-found not found"

**Issue**: Workspace package filtering doesn't work

**Solution**:
1. Verify `package.json` in root has correct workspace definition
2. Verify frontend is at `frontend/` (not `artifacts/lost-and-found/`)
3. Check pnpm-workspace.yaml includes `frontend` in packages list
4. Try build command without filter: `pnpm run build` (builds all)

### Frontend Shows Blank Page

**Issue**: React mounts but no content appears

**Solution**:
1. Check browser console for JavaScript errors
2. Verify `public/index.html` exists in output
3. Check `BASE_PATH` env var (should be `/`)
4. Verify Vite build succeeded (check logs)

### API Calls Fail with CORS Error

**Issue**: Browser blocks API requests with CORS error

```
Access to XMLHttpRequest from 'https://app.vercel.app' has been blocked by CORS policy
```

**Solution**:
1. Verify `VITE_API_URL` is correctly set in Vercel dashboard
2. Verify backend `ALLOWED_ORIGINS` includes your Vercel domain
3. Check backend is running and accessible via curl:
   ```bash
   curl https://college-connect-api-xxxx.onrender.com/api/health
   ```
4. If backend is asleep (free tier), wake it up by visiting health endpoint
5. Check browser DevTools → Network tab to see actual request URL and CORS headers

### Auth Token Not Persisting

**Issue**: User logs in, page refreshes, user is logged out

**Solution**:
1. Check browser localStorage is enabled
2. Verify `setAuthTokenGetter` is called in `main.tsx`
3. Backend should return JWT in response body
4. Frontend saves to localStorage on login
5. Check DevTools → Application → Local Storage for `jwt_token` key

### Slow Builds

**Current**: ~2 minutes for first build, ~1 minute for cached rebuilds

**To optimize:**
1. Split monorepo deps: move frontend deps to `frontend/package.json` only
2. Use pnpm `frozen-lockfile` (already set)
3. Consider Vercel's build cache settings
4. Move heavy deps (like TailwindCSS) to dev-only

## Production Checklist

Before going live:

- [ ] `VITE_API_URL` is set to production backend URL
- [ ] Backend API is running and responding to requests
- [ ] CORS is configured correctly (not `*` if using custom domain)
- [ ] Frontend login/register flow works end-to-end
- [ ] Feed loads items from backend successfully
- [ ] Claims and OTP verification flows work
- [ ] Admin dashboard (if user is admin) loads stats and data
- [ ] Chat endpoint works (even if mocked response)
- [ ] Error pages display correctly (404, 500, etc.)
- [ ] Mobile responsive (test on phone/tablet)
- [ ] HTTPS is enforced (should be default on Vercel)

## Local Testing Before Deployment

Test production build locally:

```bash
cd frontend

# Build
pnpm run build

# Preview (serves dist/public locally)
VITE_API_URL=http://localhost:8080 pnpm run serve
```

Visit `http://localhost:3000` and test flows.

## Next Steps

- Move to Phase 6: Docker Compose setup for local development
- Move to Phase 7: Documentation (SYSTEM_ARCHITECTURE.md, LOCAL_DEVELOPMENT.md, DEPLOYMENT_GUIDE.md, ENV_VARIABLES.md)
- Move to Phase 8: Final verification and architecture review

For more details, see [Vercel Framework Guides](https://vercel.com/docs) and [Vite Deployment Guide](https://vitejs.dev/guide/ssr.html).
