-- Real place names only. No boundaries or coordinates are invented:
-- boundary/centroid stay NULL until imported from geoBoundaries / OpenStreetMap.
INSERT INTO areas (type, name, slug, code, source, provenance)
VALUES ('continent', 'Africa', 'africa', NULL, 'place name', 'public_data')
ON CONFLICT (slug) WHERE parent_id IS NULL DO NOTHING;

INSERT INTO areas (parent_id, type, name, slug, code, source, provenance)
SELECT id, 'country', 'Nigeria', 'nigeria', 'NG', 'place name', 'public_data'
FROM areas WHERE slug = 'africa' AND parent_id IS NULL
ON CONFLICT (parent_id, slug) DO NOTHING;

INSERT INTO areas (parent_id, type, name, slug, source, provenance)
SELECT id, 'state', 'Oyo State', 'oyo', 'place name', 'public_data'
FROM areas WHERE slug = 'nigeria'
ON CONFLICT (parent_id, slug) DO NOTHING;

INSERT INTO areas (parent_id, type, name, slug, source, provenance)
SELECT id, 'city', 'Ibadan', 'ibadan', 'place name', 'public_data'
FROM areas WHERE slug = 'oyo'
ON CONFLICT (parent_id, slug) DO NOTHING;
