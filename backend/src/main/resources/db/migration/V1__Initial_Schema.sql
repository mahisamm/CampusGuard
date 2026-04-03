-- ============================================================================
-- CampusGuard Initial Database Schema (PostgreSQL)
-- ============================================================================
-- This script initializes the PostgreSQL database schema for CampusGuard.
-- 
-- Generated from Drizzle ORM schema definitions:
-- - backend/lib/db/src/schema/*.ts
--
-- NOTE: Hibernate (Spring Boot) will auto-apply this schema via application.yml
-- (jpa.hibernate.ddl-auto: update)
-- ============================================================================

-- ============================================================================
-- ENUMS (Custom types)
-- ============================================================================

-- User roles enum
CREATE TYPE user_role AS ENUM ('student', 'faculty', 'admin');

-- Item type enum (lost or found item)
CREATE TYPE item_type AS ENUM ('lost', 'found');

-- Item status enum
CREATE TYPE item_status AS ENUM ('active', 'claimed', 'returned');

-- ============================================================================
-- TABLES
-- ============================================================================

-- Users table: Students, Faculty, Admins
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'student',
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Lost and Found Items
CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    type item_type NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    location TEXT NOT NULL,
    image_url TEXT,
    status item_status NOT NULL DEFAULT 'active',
    reported_by INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Claims: User claims on items
CREATE TABLE IF NOT EXISTS claims (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES items(id),
    claimer_id INTEGER NOT NULL REFERENCES users(id),
    message TEXT NOT NULL,
    otp TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending | verified | rejected
    flagged BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP
);

-- Conversations: Chat history
CREATE TABLE IF NOT EXISTS conversations (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Messages: Chat messages within conversations
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- OTPs: One-Time Passwords for registration/login verification
CREATE TABLE IF NOT EXISTS otps (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    code TEXT NOT NULL,
    type TEXT NOT NULL, -- "registration" | "login"
    used BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Email lookup (users and otps)
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_otps_email ON otps(email);

-- Foreign key queries
CREATE INDEX idx_items_reported_by ON items(reported_by);
CREATE INDEX idx_claims_item_id ON claims(item_id);
CREATE INDEX idx_claims_claimer_id ON claims(claimer_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);

-- Status lookups
CREATE INDEX idx_items_status ON items(status);
CREATE INDEX idx_claims_status ON claims(status);

-- OTP lookups
CREATE INDEX idx_otps_code ON otps(code);
CREATE INDEX idx_otps_expires_at ON otps(expires_at);

-- ============================================================================
-- COMMENTS (Documentation)
-- ============================================================================

COMMENT ON TABLE users IS 'College users: students, faculty, admins';
COMMENT ON TABLE items IS 'Lost and found items reported by users';
COMMENT ON TABLE claims IS 'Claims on items with OTP verification workflow';
COMMENT ON TABLE conversations IS 'AI chat conversations for helping with claims';
COMMENT ON TABLE messages IS 'Messages within conversations (user/assistant roles)';
COMMENT ON TABLE otps IS 'One-time passwords for email verification';

COMMENT ON COLUMN users.role IS 'User role: student, faculty, or admin';
COMMENT ON COLUMN users.is_verified IS 'Email verification status';
COMMENT ON COLUMN items.type IS 'Item type: lost (user lost it) or found (user found it)';
COMMENT ON COLUMN items.status IS 'Item status: active (open), claimed (resolved), or returned';
COMMENT ON COLUMN claims.status IS 'Claim status: pending, verified (OTP confirmed), or rejected';
COMMENT ON COLUMN otps.type IS 'OTP purpose: registration or login verification';

-- ============================================================================
-- SEED DATA (Optional - Comment out if not needed)
-- ============================================================================

-- Sample admin user (password: admin123 - CHANGE IN PRODUCTION!)
-- INSERT INTO users (name, email, password_hash, role, is_admin, is_verified)
-- VALUES ('Admin User', 'admin@college.edu', '$2a$10$...', 'admin', TRUE, TRUE)
-- ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- Notes
-- ============================================================================
-- 1. Hibernate (Spring Boot) manages schema updates via ddl-auto: update
-- 2. This file documents the expected schema structure
-- 3. Indices are already created by Hibernate via @Index annotations
-- 4. Foreign key constraints are enforced for data integrity
-- 5. Timestamps use UTC by default (TIMESTAMP WITH TIME ZONE where needed)
