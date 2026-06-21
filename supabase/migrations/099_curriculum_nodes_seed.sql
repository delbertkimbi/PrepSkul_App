-- Phase B2: Seed curriculum_nodes from bundled JSON corpus (keywords for matcher sync).

ALTER TABLE public.curriculum_nodes
  ADD COLUMN IF NOT EXISTS keywords TEXT[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.curriculum_nodes.keywords IS
  'Matcher keywords (internal). Synced from PrepSkul_Web/data/curriculum/seed-nodes.json.';

INSERT INTO public.curriculum_frameworks (id, country_code, education_subsystem, label_en, label_fr, exam_board)
VALUES
  ('open_learning', 'GLOBAL', 'open', 'Open learning', 'Apprentissage libre', NULL),
  ('cm_gce_ol', 'CM', 'anglophone', 'GCE Ordinary Level', 'GCE niveau O', 'GCE_OL'),
  ('cm_gce_al', 'CM', 'anglophone', 'GCE Advanced Level', 'GCE niveau A', 'GCE_AL'),
  ('cm_francophone', 'CM', 'francophone', 'Francophone secondary', 'Secondaire francophone', 'BEPC_PROBATOIRE'),
  ('waec', 'GLOBAL', 'anglophone', 'WAEC', 'WAEC', 'WAEC'),
  ('steam', 'GLOBAL', 'open', 'STEAM', 'STEAM', NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.curriculum_nodes (
  framework_id,
  subject_code,
  topic_id,
  title_en,
  title_fr,
  grade_levels,
  objectives,
  keywords,
  sort_order
)
VALUES
  ('cm_gce_ol', 'mathematics', 'gce_ol_math_number', 'Number and calculation', 'Nombres et calcul', ARRAY['form_3','form_4','form_5']::text[], '["Perform operations with fractions and decimals","Apply ratios and percentages in problems"]'::jsonb, ARRAY['fraction','decimal','percentage','ratio','standard form','indices','surds']::text[], 0),
  ('cm_gce_ol', 'mathematics', 'gce_ol_math_algebra', 'Algebra and equations', 'Algèbre et équations', ARRAY['form_3','form_4','form_5']::text[], '["Solve linear and quadratic equations","Factorise algebraic expressions"]'::jsonb, ARRAY['algebra','equation','factoris','quadratic','simultaneous','inequalit','polynomial']::text[], 1),
  ('cm_gce_ol', 'mathematics', 'gce_ol_math_geometry', 'Geometry and mensuration', 'Géométrie et mesure', ARRAY['form_3','form_4','form_5']::text[], '["Calculate areas and volumes","Apply angle properties and Pythagoras theorem"]'::jsonb, ARRAY['angle','triangle','circle','area','volume','perimeter','theorem','pythagoras']::text[], 2),
  ('cm_gce_ol', 'mathematics', 'gce_ol_math_trig', 'Trigonometry', 'Trigonométrie', ARRAY['form_4','form_5']::text[], '["Use sine, cosine and tangent ratios","Solve problems involving bearings"]'::jsonb, ARRAY['trigonometr','sine','cosine','tangent','sohcahtoa','bearing']::text[], 3),
  ('cm_gce_ol', 'mathematics', 'gce_ol_math_stats', 'Statistics and probability', 'Statistiques et probabilités', ARRAY['form_4','form_5']::text[], '["Calculate measures of central tendency","Interpret graphs and basic probability"]'::jsonb, ARRAY['mean','median','mode','histogram','probability','frequency','scatter']::text[], 4),
  ('cm_gce_ol', 'chemistry', 'gce_ol_chem_atomic', 'Atomic structure and periodic table', 'Structure atomique et tableau périodique', ARRAY['form_3','form_4','form_5']::text[], '["Describe atomic structure","Relate position in periodic table to properties"]'::jsonb, ARRAY['atom','proton','neutron','electron','periodic','isotope','shell']::text[], 5),
  ('cm_gce_ol', 'chemistry', 'gce_ol_chem_bonding', 'Chemical bonding', 'Liaisons chimiques', ARRAY['form_4','form_5']::text[], '["Compare ionic and covalent bonding","Predict bond type from properties"]'::jsonb, ARRAY['ionic','covalent','metallic','bond','molecule','lattice','intermolecular']::text[], 6),
  ('cm_gce_ol', 'chemistry', 'gce_ol_chem_stoich', 'Stoichiometry and equations', 'Stœchiométrie et équations', ARRAY['form_4','form_5']::text[], '["Balance chemical equations","Calculate moles and reacting masses"]'::jsonb, ARRAY['mole','stoichiometr','balanced equation','avogadro','concentration','molar']::text[], 7),
  ('cm_gce_ol', 'chemistry', 'gce_ol_chem_acids', 'Acids, bases and salts', 'Acides, bases et sels', ARRAY['form_4','form_5']::text[], '["Explain neutralisation","Prepare and identify salts"]'::jsonb, ARRAY['acid','base','alkali','ph','neutralis','salt','indicator']::text[], 8),
  ('cm_gce_ol', 'chemistry', 'gce_ol_chem_electrolysis', 'Electrolysis', 'Électrolyse', ARRAY['form_4','form_5']::text[], '["Explain electrolysis of molten and aqueous compounds","Predict products at electrodes"]'::jsonb, ARRAY['electrolys','electrode','anode','cathode','electrolyte','discharge']::text[], 9),
  ('cm_gce_ol', 'chemistry', 'gce_ol_chem_organic', 'Organic chemistry basics', 'Chimie organique de base', ARRAY['form_5']::text[], '["Name simple organic compounds","Describe reactions of alkanes and alkenes"]'::jsonb, ARRAY['alkane','alkene','alcohol','carboxylic','hydrocarbon','polymer','cracking']::text[], 10),
  ('cm_gce_ol', 'biology', 'gce_ol_bio_cells', 'Cells and microscopy', 'Cellules et microscopie', ARRAY['form_3','form_4','form_5']::text[], '["Identify cell structures","Compare plant and animal cells"]'::jsonb, ARRAY['cell','organelle','mitochondr','chloroplast','nucleus','microscope','membrane']::text[], 11),
  ('cm_gce_ol', 'biology', 'gce_ol_bio_nutrition', 'Nutrition and digestion', 'Nutrition et digestion', ARRAY['form_3','form_4','form_5']::text[], '["Describe digestion of major food groups","Explain role of enzymes"]'::jsonb, ARRAY['digest','enzyme','nutrition','absorption','amylase','protease','lipase']::text[], 12),
  ('cm_gce_ol', 'biology', 'gce_ol_bio_transport', 'Transport in organisms', 'Transport dans les organismes', ARRAY['form_4','form_5']::text[], '["Explain blood circulation in humans","Describe transport in plants"]'::jsonb, ARRAY['circulat','heart','blood','xylem','phloem','transpiration','capillar']::text[], 13),
  ('cm_gce_ol', 'biology', 'gce_ol_bio_respiration', 'Respiration and gas exchange', 'Respiration et échanges gazeux', ARRAY['form_4','form_5']::text[], '["Compare aerobic and anaerobic respiration","Describe gas exchange in lungs"]'::jsonb, ARRAY['respiration','aerobic','anaerobic','lung','alveol','oxygen','carbon dioxide']::text[], 14),
  ('cm_gce_ol', 'biology', 'gce_ol_bio_genetics', 'Genetics and inheritance', 'Génétique et hérédité', ARRAY['form_5']::text[], '["Explain inheritance patterns","Use Punnett squares for monohybrid crosses"]'::jsonb, ARRAY['dna','gene','chromosome','allele','dominant','recessive','inherit','punnett']::text[], 15),
  ('cm_gce_al', 'mathematics', 'gce_al_math_calculus', 'Differentiation and integration', 'Dérivation et intégration', ARRAY['lower_sixth','upper_sixth']::text[], '["Differentiate standard functions","Apply integration to find areas"]'::jsonb, ARRAY['differentiat','integrat','derivative','gradient','area under curve','limit']::text[], 16),
  ('cm_gce_al', 'mathematics', 'gce_al_math_mechanics', 'Mechanics', 'Mécanique', ARRAY['lower_sixth','upper_sixth']::text[], '["Solve motion problems using calculus","Apply Newton''s laws"]'::jsonb, ARRAY['velocity','acceleration','force','momentum','projectile','newton']::text[], 17),
  ('cm_gce_al', 'chemistry', 'gce_al_chem_thermo', 'Energetics and thermochemistry', 'Énergétique et thermochimie', ARRAY['lower_sixth','upper_sixth']::text[], '["Calculate enthalpy changes","Use Hess''s law"]'::jsonb, ARRAY['enthalpy','exothermic','endothermic','hess','born-haber','lattice energy']::text[], 18),
  ('cm_gce_al', 'chemistry', 'gce_al_chem_equilib', 'Chemical equilibrium', 'Équilibre chimique', ARRAY['lower_sixth','upper_sixth']::text[], '["Apply Le Chatelier''s principle","Calculate equilibrium constants"]'::jsonb, ARRAY['equilibrium','le chatelier','kp','kc','reversible']::text[], 19),
  ('cm_gce_al', 'biology', 'gce_al_bio_biochem', 'Biochemistry', 'Biochimie', ARRAY['lower_sixth','upper_sixth']::text[], '["Describe structure of biological macromolecules","Explain enzyme action"]'::jsonb, ARRAY['protein','amino acid','lipid','carbohydrate','enzyme kinetics','atp']::text[], 20),
  ('steam', 'computer_science', 'steam_cs_basics', 'Computing and programming basics', 'Informatique et programmation', ARRAY['open']::text[], '["Write simple algorithms","Use variables and control structures"]'::jsonb, ARRAY['algorithm','programming','python','variable','loop','function','code']::text[], 21),
  ('steam', 'computer_science', 'steam_ml_intro', 'Machine learning introduction', 'Introduction au machine learning', ARRAY['open']::text[], '["Explain basic ML concepts","Describe training and inference at a high level"]'::jsonb, ARRAY['machine learning','neural network','deep learning','training','model','dataset','supervised']::text[], 22)
ON CONFLICT (topic_id) DO UPDATE SET
  framework_id = EXCLUDED.framework_id,
  subject_code = EXCLUDED.subject_code,
  title_en = EXCLUDED.title_en,
  title_fr = EXCLUDED.title_fr,
  grade_levels = EXCLUDED.grade_levels,
  objectives = EXCLUDED.objectives,
  keywords = EXCLUDED.keywords,
  sort_order = EXCLUDED.sort_order;
