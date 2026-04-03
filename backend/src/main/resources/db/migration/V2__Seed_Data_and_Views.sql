-- ============================================================================
-- CampusGuard Database Seed Data and Maintenance
-- ============================================================================
-- Optional seed data and utility statements for development/testing
-- Run this AFTER V1__Initial_Schema.sql
-- ============================================================================

-- ============================================================================
-- SAMPLE DATA FOR TESTING (Development Only)
-- ============================================================================
-- Uncomment these INSERT statements to populate test data

-- Sample Users
-- INSERT INTO users (name, email, password_hash, role, is_admin, is_verified)
-- VALUES 
--   ('John Student', 'john@college.edu', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36DH..', 'student', FALSE, TRUE),
--   ('Jane Faculty', 'jane@college.edu', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36DH..', 'faculty', FALSE, TRUE),
--   ('Admin User', 'admin@college.edu', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36DH..', 'admin', TRUE, TRUE)
-- ON CONFLICT (email) DO NOTHING;

-- Sample Items
-- INSERT INTO items (type, title, description, category, location, status, reported_by)
-- VALUES 
--   ('lost', 'Blue Backpack', 'Navy blue backpack with laptop compartment', 'bags', 'Library 3rd Floor', 'active', 1),
--   ('found', 'Black iPhone 13', 'Found in Student Center cafeteria', 'electronics', 'Student Center', 'active', 2),
--   ('lost', 'University ID Card', 'Name: John Student, ID: 123456', 'documents', 'Dormitory Building A', 'claimed', 1)
-- ON CONFLICT DO NOTHING;

-- ============================================================================
-- UTILITY VIEWS (Optional)
-- ============================================================================

-- Recent claims view
CREATE OR REPLACE VIEW v_recent_claims AS
SELECT 
    c.id,
    i.title as item_title,
    i.type,
    u_reporter.name as reported_by,
    u_claimer.name as claimer_name,
    c.status,
    c.created_at,
    AGE(CURRENT_TIMESTAMP, c.created_at) as time_pending
FROM claims c
JOIN items i ON c.item_id = i.id
JOIN users u_reporter ON i.reported_by = u_reporter.id
JOIN users u_claimer ON c.claimer_id = u_claimer.id
ORDER BY c.created_at DESC;

-- Active items view
CREATE OR REPLACE VIEW v_active_items AS
SELECT 
    i.id,
    i.type,
    i.title,
    i.category,
    i.location,
    u.name as reported_by,
    i.created_at,
    (SELECT COUNT(*) FROM claims WHERE item_id = i.id AND status != 'rejected') as claim_count
FROM items i
JOIN users u ON i.reported_by = u.id
WHERE i.status = 'active'
ORDER BY i.created_at DESC;

-- User statistics view
CREATE OR REPLACE VIEW v_user_stats AS
SELECT 
    u.id,
    u.name,
    u.email,
    u.role,
    COUNT(DISTINCT i.id) as items_reported,
    COUNT(DISTINCT c.id) as claims_made,
    u.created_at
FROM users u
LEFT JOIN items i ON u.id = i.reported_by
LEFT JOIN claims c ON u.id = c.claimer_id
GROUP BY u.id, u.name, u.email, u.role, u.created_at;

-- ============================================================================
-- MAINTENANCE QUERIES
-- ============================================================================
-- These can be run manually to maintain database health

-- Remove expired OTPs (older than 1 hour)
-- DELETE FROM otps WHERE expires_at < CURRENT_TIMESTAMP;

-- Archive old conversations (older than 30 days, no recent messages)
-- DELETE FROM conversations 
-- WHERE id NOT IN (
--   SELECT DISTINCT conversation_id FROM messages 
--   WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
-- );

-- Reset claimed items to active if claim was rejected (status: rejected)
-- UPDATE items SET status = 'active' 
-- WHERE status = 'claimed' AND id IN (
--   SELECT item_id FROM claims WHERE status = 'rejected'
-- );

-- ============================================================================
-- CONSTRAINTS & TRIGGERS (Optional - Enforce business logic)
-- ============================================================================

-- Prevent duplicate claims on same item by same user
CREATE OR REPLACE FUNCTION check_duplicate_claim()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM claims 
        WHERE item_id = NEW.item_id 
        AND claimer_id = NEW.claimer_id 
        AND status IN ('pending', 'verified')
    ) THEN
        RAISE EXCEPTION 'User already has an active claim on this item';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_duplicate_claim
BEFORE INSERT ON claims
FOR EACH ROW
EXECUTE FUNCTION check_duplicate_claim();

-- Auto-update item status when claim is verified
CREATE OR REPLACE FUNCTION update_item_on_claim_verified()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'verified' AND OLD.status != 'verified' THEN
        UPDATE items SET status = 'claimed' WHERE id = NEW.item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_item_on_claim_verified
AFTER UPDATE ON claims
FOR EACH ROW
EXECUTE FUNCTION update_item_on_claim_verified();

-- ============================================================================
-- PERFORMANCE TUNING (Optional)
-- ============================================================================

-- Analyze tables for query planner (run after importing data)
-- ANALYZE users;
-- ANALYZE items;
-- ANALYZE claims;
-- ANALYZE conversations;
-- ANALYZE messages;

-- ============================================================================
-- Notes
-- ============================================================================
-- 1. Seed data is helpful for local development and testing
-- 2. Views simplify common queries and provide data aggregations
-- 3. Triggers enforce business logic at database level
-- 4. Maintenance queries help keep database clean
-- 5. Performance tuning should be done after data import in production
