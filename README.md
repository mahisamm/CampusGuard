# CampusGuard

CampusGuard is structured for a production-style split architecture:

- `frontend/`: React/Vite client application
- `backend/`: Spring Boot API service and backend-owned libraries
- `docker/`: container and orchestration assets
- `docs/`: architecture and deployment documentation

Supporting directories:

- `scripts/`: workspace utility scripts
- root configs: `package.json`, `pnpm-workspace.yaml`, `tsconfig*.json`, `render.yaml`

## Current Deployment Direction

- Frontend: Vercel
- Backend: Render (Docker runtime)
- Database: Render PostgreSQL

Detailed analysis is available in `ARCHITECTURE_ANALYSIS.md`.
