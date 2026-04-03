# Phase 4: Database Setup & Configuration

## Overview

This document covers all aspects of CampusGuard database setup, configuration, and management for **PostgreSQL** across development, Docker, and production environments.

**Current Configuration:**
- **Primary Database:** PostgreSQL 16
- **ORM:** Spring Boot JPA with Hibernate (auto-schema management)
- **Schema Definition:** Drizzle ORM TypeScript schemas (`backend/lib/db/src/schema/`)
- **Dev Alternative:** H2 in-memory (for quick testing without Docker)
- **Docker Stack:** PostgreSQL 16-alpine in docker-compose.yml
- **Production:** Render.com managed PostgreSQL

---

## Table of Contents

1. [Database Architecture](#database-architecture)
2. [Schema Overview](#schema-overview)
3. [Setup Instructions](#setup-instructions)
   - [Local Development (H2)](#local-development-h2)
   - [Local Development (PostgreSQL)](#local-development-postgresql)
   - [Docker Compose](#docker-compose)
   - [Production (Render)](#production-render)
4. [CORS Configuration](#cors-configuration)
5. [Environment Variables](#environment-variables)
6. [Migrations & Schema Management](#migrations--schema-management)
7. [Troubleshooting](#troubleshooting)
8. [Security Best Practices](#security-best-practices)

---

## Database Architecture

### Entity Relationship Diagram

```
┌─────────────┐
│   USERS     │ (Student, Faculty, Admin)
├─────────────┤
│ id (PK)     │
│ email (UK)  │
│ name        │
│ role        │
│ is_verified │
│ created_at  │
└─────────────┘
       △
       │ (1:N)
       │
┌──────┴───────┬──────────────────────────────────────┐
│              │                                      │
│              │                                      │
┌──────────────▼─────┐                    ┌──────────▼──────┐
│     ITEMS          │                    │     CLAIMS      │
├────────────────────┤                    ├─────────────────┤
│ id (PK)            │◄───────────────────│ id (PK)         │
│ type (lost/found)  │   item_id (FK)     │ item_id (FK)    │
│ title              │                    │ claimer_id (FK) │
│ description        │                    │ message         │
│ category           │                    │ otp             │
│ location           │                    │ status          │
│ image_url          │                    │ verified_at     │
│ status             │                    │ created_at      │
│ reported_by (FK)───┼───────────────────►│                 │
│ created_at         │                    │ claimer_id (FK) │
└────────────────────┘                    └─────────────────┘
                                                  △
                                                  │
                                                  └──── USERS (1:N)

┌──────────────────────┐
│  CONVERSATIONS       │ (AI Chat History)
├──────────────────────┤
│ id (PK)              │
│ title                │
│ created_at           │
└──────────────────────┘
       │ (1:N)
       │
       ▼
┌──────────────────────┐
│    MESSAGES          │
├──────────────────────┤
│ id (PK)              │
│ conversation_id (FK) │
│ role (user/assistant)
│ content              │
│ created_at           │
└──────────────────────┘

┌──────────────────────┐
│     OTPS             │ (Email Verification)
├──────────────────────┤
│ id (PK)              │
│ email                │
│ code                 │
│ type (reg/login)     │
│ used                 │
│ expires_at           │
│ created_at           │
└──────────────────────┘
```

### Enums

| Enum | Values | Usage |
|------|--------|-------|
| `user_role` | `student`, `faculty`, `admin` | Users table - role classification |
| `item_type` | `lost`, `found` | Items table - lost item or found item |
| `item_status` | `active`, `claimed`, `returned` | Items table - claim resolution state |

---

## Schema Overview

### Tables

#### 1. **USERS** - College members
```sql
- id (PK): Serial
- email (UK): Text - Unique email for login
- name: Text - Full name
- password_hash: Text - Bcrypt hashed password
- role: Enum - student | faculty | admin
- is_admin: Boolean - Quick admin flag check
- is_verified: Boolean - Email verification status
- created_at: Timestamp - Account creation time
```

#### 2. **ITEMS** - Lost and found items
```sql
- id (PK): Serial
- type: Enum - lost | found (user lost it or found it)
- title: Text - Item name (e.g., "BlackBackpack")
- description: Text - Detailed description
- category: Text - bags, electronics, documents, etc.
- location: Text - Where lost/found (e.g., "Library 3rd Floor")
- image_url: Text - Image URL for item
- status: Enum - active | claimed | returned
- reported_by (FK): Users.id - Who reported it
- created_at: Timestamp - When reported
```

#### 3. **CLAIMS** - User claims on items
```sql
- id (PK): Serial
- item_id (FK): Items.id - Which item being claimed
- claimer_id (FK): Users.id - Who is claiming
- message: Text - Claim message/description
- otp: Text - OTP verification code
- status: Text - pending | verified | rejected
- flagged: Boolean - Marked for review by admin
- created_at: Timestamp - Claim submission time
- verified_at: Timestamp - When claim was verified
```

#### 4. **CONVERSATIONS** - AI chat sessions
```sql
- id (PK): Serial
- title: Text - Conversation title
- created_at: Timestamp with timezone - Session start
```

#### 5. **MESSAGES** - Messages in conversations
```sql
- id (PK): Serial
- conversation_id (FK): Conversations.id - Parent conversation
- role: Text - "user" or "assistant"
- content: Text - Message content
- created_at: Timestamp with timezone - Message time
```

#### 6. **OTPS** - One-time passwords for email verification
```sql
- id (PK): Serial
- email: Text - Target email
- code: Text - OTP code
- type: Text - "registration" | "login"
- used: Boolean - Has been used
- expires_at: Timestamp - Expiration time (usually 10 minutes)
- created_at: Timestamp - Generation time
```

---

## Setup Instructions

### Option 1: Local Development (H2) - Fastest

**Best for:** Quick testing, no external dependencies

#### Steps:

1. **Set H2 database in `.env` or `application.yml`:**

   ```ini
   # In backend/.env or set application.yml defaults
   DATABASE_URL=jdbc:h2:mem:college_connect;DB_CLOSE_DELAY=-1;MODE=PostgreSQL
   DATABASE_USERNAME=sa
   DATABASE_PASSWORD=
   DATABASE_DRIVER=org.h2.Driver
   HIBERNATE_DIALECT=org.hibernate.dialect.H2Dialect
   ```

2. **Run backend:**

   ```bash
   cd backend
   mvn spring-boot:run
   ```

3. **Access H2 Console (optional):**

   - Open: http://localhost:8080/h2-console
   - JDBC URL: `jdbc:h2:mem:college_connect`
   - User: `sa`
   - Password: _(leave blank)_

#### Limitations:
- Data lost on restart
- In-memory only (not production-ready)
- PostgreSQL syntax compatibility mode

---

### Option 2: Local Development (PostgreSQL) - Recommended

**Best for:** Production testing, persistent data

#### Prerequisites:

Install PostgreSQL 16:
- **macOS:** `brew install postgresql@16`
- **Windows:** https://www.postgresql.org/download/windows/
- **Linux:** `sudo apt install postgresql-16`

#### Steps:

1. **Create local PostgreSQL database:**

   ```bash
   # Connect to PostgreSQL
   psql -U postgres
   
   # Create database
   CREATE DATABASE college_connect;
   CREATE USER college_admin WITH PASSWORD 'college_password';
   GRANT ALL PRIVILEGES ON DATABASE college_connect TO college_admin;
   \q
   ```

2. **Configure backend `.env`:**

   ```ini
   DATABASE_URL=jdbc:postgresql://localhost:5432/college_connect
   DATABASE_USERNAME=college_admin
   DATABASE_PASSWORD=college_password
   DATABASE_DRIVER=org.postgresql.Driver
   HIBERNATE_DIALECT=org.hibernate.dialect.PostgreSQLDialect
   ```

3. **Run backend:**

   ```bash
   cd backend
   mvn spring-boot:run
   ```

4. **Verify schema created:**

   ```bash
   psql -U college_admin -d college_connect
   
   \dt  # List tables
   SELECT * FROM users;  # Should be empty, schema created
   \q
   ```

#### Using Docker for PostgreSQL Only:

If you don't want to install PostgreSQL locally:

```bash
# Run PostgreSQL in Docker
docker run -d \
  --name postgresql \
  -e POSTGRES_USER=college_admin \
  -e POSTGRES_PASSWORD=college_password \
  -e POSTGRES_DB=college_connect \
  -p 5432:5432 \
  postgres:16-alpine

# Test connection
docker exec -it postgresql psql -U college_admin -d college_connect -c '\dt'
```

---

### Option 3: Docker Compose - Complete Stack

**Best for:** Isolated development environment, testing full stack

#### Prerequisites:

- Docker & Docker Compose installed

#### Steps:

1. **Create `docker/.env` from template:**

   ```bash
   cp docker/.env.example docker/.env
   ```

2. **Start services:**

   ```bash
   cd docker
   docker-compose up -d
   ```

3. **Verify services:**

   ```bash
   docker-compose ps
   docker-compose logs backend
   docker-compose logs postgres
   ```

4. **Test backend health:**

   ```bash
   curl http://localhost:8080/api/health
   ```

5. **Access PostgreSQL from host:**

   ```bash
   psql -h localhost -U college_admin -d college_connect
   ```

6. **Stop services:**

   ```bash
   docker-compose down
   ```

7. **Reset database (delete volume):**

   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

#### Useful Compose Commands:

```bash
# View all services
docker-compose ps

# View backend logs
docker-compose logs -f backend

# View PostgreSQL logs
docker-compose logs -f postgres

# Execute command in backend container
docker-compose exec backend bash

# Restart a service
docker-compose restart backend

# Stop all services
docker-compose stop

# Start stopped services
docker-compose start

# Remove everything (keep volumes)
docker-compose down

# Remove everything including volumes (reset database)
docker-compose down -v
```

---

### Option 4: Production (Render.com) - Managed Database

**Best for:** Production deployment

#### Prerequisites:

- Render.com account (free tier available)
- GitHub repository for backend code

#### Steps:

1. **In Render Dashboard:**

   - Go to **Database** → **Create Database**
   - Database: PostgreSQL
   - Name: `college-connect`
   - Region: Choose closest to users
   - Plan: Free or Paid

2. **Note the connection string:**

   ```
   postgresql://user:password@hostname:5432/database
   ```

3. **Create Web Service for Backend:**

   - Go to **Services** → **Create Service**
   - Repository: Link your GitHub repo (backend folder)
   - Name: `college-connect-api`
   - Region: Same as database
   - Environment Variables:

     ```
     DATABASE_URL=postgresql://...  # From step 2
     DATABASE_USERNAME=...
     DATABASE_PASSWORD=...
     DATABASE_DRIVER=org.postgresql.Driver
     HIBERNATE_DIALECT=org.hibernate.dialect.PostgreSQLDialect
     JWT_SECRET=<auto-generate or set your own>
     ALLOWED_ORIGINS=https://yourdomain.vercel.app
     ```

4. **Set build command:**

   ```bash
   cd backend && mvn clean package -DskipTests
   ```

5. **Set start command:**

   ```bash
   java -jar target/*.jar
   ```

6. **Deploy:**

   - Click **Deploy**
   - Monitor build logs
   - Test endpoints once deployed

See: [backend/RENDER_DEPLOY.md](./RENDER_DEPLOY.md) for detailed Render setup.

---

## CORS Configuration

**Current Policy:** Allow all origins (`*`) for college project

### Configuration Files:

1. **`backend/src/main/resources/application.yml`:**

   ```yaml
   cors:
     allowed-origins: ${ALLOWED_ORIGINS:*}
   ```

2. **`backend/src/main/java/com/collegeconnect/backend/config/SecurityConfig.java`:**

   ```java
   public CorsConfigurationSource corsConfigurationSource() {
       CorsConfiguration configuration = new CorsConfiguration();
       
       if ("*".equals(allowedOrigins.trim())) {
           configuration.setAllowedOriginPatterns("*");
       } else {
           configuration.setAllowedOrigins(...);
       }
       
       configuration.setAllowedMethods(...);
       configuration.setAllowCredentials(true);
       // ...
   }
   ```

### Environment Variables:

| Environment | ALLOWED_ORIGINS Value |
|-------------|----------------------|
| **Dev** | `http://localhost:5173,http://localhost:3000` |
| **Docker** | `http://localhost:5173,http://localhost:3000,http://localhost:80` |
| **Production (Render)** | `*` (college project) or `https://yourdomain.vercel.app` (specific domain) |

### To Restrict CORS in Production:

Replace `ALLOWED_ORIGINS=*` with:

```yaml
ALLOWED_ORIGINS=https://yourdomain.vercel.app,https://www.yourdomain.vercel.app
```

Then restart the backend service.

---

## Environment Variables

### PostgreSQL Connection

| Variable | Dev | Docker | Production |
|----------|-----|--------|-----------|
| `DATABASE_URL` | `jdbc:postgresql://localhost:5432/college_connect` | `jdbc:postgresql://postgres:5432/college_connect` | _(see Render)_ |
| `DATABASE_USERNAME` | `college_admin` | `college_admin` | _(auto-injected)_ |
| `DATABASE_PASSWORD` | `college_password` | `college_password` | _(auto-injected)_ |
| `DATABASE_DRIVER` | `org.postgresql.Driver` | `org.postgresql.Driver` | `org.postgresql.Driver` |
| `HIBERNATE_DIALECT` | `org.hibernate.dialect.PostgreSQLDialect` | `org.hibernate.dialect.PostgreSQLDialect` | `org.hibernate.dialect.PostgreSQLDialect` |

### Full `.env` Template:

See: [backend/.env.example](../.env.example)

---

## Migrations & Schema Management

### Automatic Schema Management

Hibernate automatically manages schema via `application.yml`:

```yaml
jpa:
  hibernate:
    ddl-auto: update  # Automatically create/update tables
```

**How it works:**
1. Backend starts
2. Reads `backend/lib/db/src/schema/*.ts` Drizzle definitions
3. Compares with database schema
4. Creates/alters tables as needed

### Manual SQL Scripts

If needed, manual migration scripts are in:

```
backend/src/main/resources/db/migration/
├── V1__Initial_Schema.sql      # Initial table creation
└── V2__Seed_Data_and_Views.sql # Sample data and views
```

**To run manually:**

```bash
# Connect to PostgreSQL
psql -h localhost -U college_admin -d college_connect < backend/src/main/resources/db/migration/V1__Initial_Schema.sql
```

### Adding New Tables

1. **Create Drizzle schema** in `backend/lib/db/src/schema/`:

   ```typescript
   // new_table.ts
   import { pgTable, serial, text } from "drizzle-orm/pg-core";
   
   export const newTable = pgTable("new_table", {
     id: serial("id").primaryKey(),
     name: text("name").notNull(),
   });
   ```

2. **Export from `backend/lib/db/src/schema/index.ts`:**

   ```typescript
   export * from "./new_table";
   ```

3. **Restart backend:**

   ```bash
   mvn spring-boot:run
   ```

   Hibernate will automatically create the table!

---

## Troubleshooting

### Issue: "Connection refused" on localhost:5432

**Cause:** PostgreSQL not running

**Solution:**
```bash
# Check if PostgreSQL is running
pg_isready -h localhost

# Start PostgreSQL
# macOS: brew services start postgresql@16
# Linux: sudo systemctl start postgresql
# Docker: docker start postgresql (or docker-compose up)
```

### Issue: "Invalid password" or "FATAL: role does not exist"

**Cause:** Wrong credentials in DATABASE_URL

**Solution:**
```bash
# Verify credentials (example)
psql -h localhost -U college_admin -d college_connect

# If user doesn't exist, create it
psql -U postgres
CREATE USER college_admin WITH PASSWORD 'college_password';
GRANT ALL PRIVILEGES ON DATABASE college_connect TO college_admin;
```

### Issue: Tables not creating automatically

**Cause:** Hibernate ddl-auto not set correctly

**Solution:**
```yaml
# In application.yml - verify
jpa:
  hibernate:
    ddl-auto: update  # Must be 'update' or 'create'
```

Then restart backend.

### Issue: "Database college_connect does not exist"

**Cause:** Database not created

**Solution:**
```bash
psql -U postgres
CREATE DATABASE college_connect;
\q
```

### Docker: "Port 5432 already in use"

**Cause:** PostgreSQL already running locally

**Solution:**
```bash
# Option 1: Use different port in docker-compose
# Change "5432:5432" to "5433:5432"

# Option 2: Stop local PostgreSQL
# macOS: brew services stop postgresql@16
# Linux: sudo systemctl stop postgresql
```

### Docker: "Backend can't connect to PostgreSQL"

**Cause:** Backend hostname should be `postgres` (service name), not `localhost`

**Solution:** Verify `docker-compose.yml` backend environment:
```yaml
environment:
  DATABASE_URL: jdbc:postgresql://postgres:5432/college_connect  # NOT localhost
```

---

## Security Best Practices

### Production Checklist:

- [ ] **Change default passwords:**
  - PostgreSQL user password
  - JWT secret (generate 32+ char random string)

- [ ] **Use environment variables** for all secrets:
  - Never commit `.env` files
  - Use `.gitignore` to exclude them

- [ ] **Restrict CORS** to specific domains:
  ```
  ALLOWED_ORIGINS=https://yourdomain.vercel.app
  ```

- [ ] **Enable HTTPS only:**
  - Render provides HTTPS automatically
  - Use SSL certificates for custom domains

- [ ] **Database backups:**
  - Render: Automated daily backups (free tier)
  - Manual: Weekly database exports

- [ ] **Monitor logs:**
  - Check Render logs for errors
  - Monitor for SQL injection attempts

### Database Security:

```sql
-- Prevent SQL injection: Use parameterized queries (Hibernate does this)
-- ✓ Good: jpql with parameters
-- ✗ Bad: String concatenation

-- Audit critical operations (optional)
-- Can add audit tables to track changes to sensitive data
```

### JWT Secret Generation:

```bash
# Generate secure JWT secret
openssl rand -hex 32

# Output example:
# 4f8c3a7b2e9d1f5a6c8b3e7d9a2f4e8a
```

---

## Verification Checklist

After setup, verify each component:

| Component | Check Command | Expected Result |
|-----------|---------------|-----------------|
| Backend | `curl http://localhost:8080/api/health` | `{"status":"UP"}` |
| PostgreSQL | `psql -U college_admin -d college_connect -c '\dt'` | List of 6 tables |
| Schema | `SELECT COUNT(*) FROM users;` | `0` (empty table) |
| CORS | Frontend to Backend API call | Successful without CORS errors |
| Docker | `docker-compose ps` | All services running |

---

## Additional Resources

- **PostgreSQL Docs:** https://www.postgresql.org/docs/16/
- **Hibernate Docs:** https://hibernate.org/
- **Spring Boot Docs:** https://spring.io/projects/spring-boot
- **Drizzle ORM:** https://orm.drizzle.team/
- **Render PostgreSQL:** https://render.com/docs/databases

---

## Next Steps

1. ✅ Choose a setup option (H2, Local PostgreSQL, Docker, or Render)
2. ✅ Configure environment variables
3. ✅ Verify database connection
4. ✅ Run backend and verify schema creation
5. ✅ Test API endpoints
6. ✅ Deploy to production (Render)

---

**Last Updated:** April 2026  
**Version:** 1.0  
**Status:** Production Ready
