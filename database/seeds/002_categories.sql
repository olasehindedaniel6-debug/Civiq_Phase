-- Starter taxonomy. Editable data: add/rename/disable rows, no code change needed.
INSERT INTO categories (slug, name, sort_order) VALUES
  ('roads','Roads',10),
  ('flooding-drainage','Flooding and drainage',20),
  ('waste','Waste',30),
  ('electricity','Electricity',40),
  ('water','Water',50),
  ('transportation','Transportation',60),
  ('public-infrastructure','Public infrastructure',70),
  ('environment','Environmental problems',80)
ON CONFLICT (slug) DO NOTHING;

WITH sub(parent, slug, name, ord) AS (VALUES
  ('roads','pothole','Pothole',1),
  ('roads','damaged-road','Damaged road',2),
  ('roads','blocked-road','Blocked road',3),
  ('roads','dangerous-road-condition','Dangerous road condition',4),
  ('flooding-drainage','flooding','Flooding',1),
  ('flooding-drainage','blocked-drainage','Blocked drainage',2),
  ('flooding-drainage','drainage-damage','Drainage damage',3),
  ('waste','illegal-dumping','Illegal dumping',1),
  ('waste','overflowing-waste','Overflowing waste location',2),
  ('electricity','power-outage','Power outage',1),
  ('electricity','damaged-pole','Damaged pole',2),
  ('electricity','transformer-issue','Transformer-related problem',3),
  ('water','water-shortage','Water shortage',1),
  ('water','water-leak','Leak',2),
  ('water','damaged-water-infrastructure','Damaged water infrastructure',3),
  ('transportation','traffic-congestion','Traffic congestion',1),
  ('transportation','accident','Accident',2),
  ('transportation','dangerous-transport-location','Dangerous transport location',3),
  ('public-infrastructure','damaged-streetlight','Damaged streetlight',1),
  ('public-infrastructure','damaged-bridge','Damaged bridge',2),
  ('public-infrastructure','damaged-public-facility','Damaged public facility',3),
  ('environment','pollution','Pollution',1),
  ('environment','environmental-hazard','Environmental hazard',2)
)
INSERT INTO categories (parent_id, slug, name, sort_order)
SELECT p.id, s.slug, s.name, s.ord
FROM sub s JOIN categories p ON p.slug = s.parent
ON CONFLICT (slug) DO NOTHING;
