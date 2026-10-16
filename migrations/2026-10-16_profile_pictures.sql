-- DermPaw database update - 16 Oct 2026
-- Run ONCE on each database (laptop MySQL Workbench AND the Azure server)
-- BEFORE starting the backend with the new code.

-- Optional profile picture for owners and vets
ALTER TABLE users
  ADD COLUMN profile_image_path VARCHAR(255) NULL,
  ADD COLUMN profile_image_updated DATETIME NULL;
