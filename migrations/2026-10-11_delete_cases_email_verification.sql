-- DermPaw database update - 11 Oct 2026
-- Run ONCE on each database (laptop MySQL Workbench AND the Azure server)
-- BEFORE starting the backend with the new code.

-- 1. Vets can remove a case from their own case history
--    (the owner's case and the vet's decision are kept)
ALTER TABLE vet_reviews
  ADD COLUMN hidden_by_vet BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. 4-digit email verification codes used during registration
--    (only a hash of the code is stored, never the code itself)
CREATE TABLE email_verifications (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  email       VARCHAR(100) NOT NULL,
  code_hash   VARCHAR(255) NOT NULL,
  expires_at  DATETIME     NOT NULL,
  attempts    INT          NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX ix_email_verifications_email (email)
);
