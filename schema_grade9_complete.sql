-- ==============================================================================
-- Wosandi Grade 9 Mission Control — Complete Supabase Database Schema
-- Supabase / PostgreSQL Schema Definition & Setup Script
-- ==============================================================================
-- Target: Wosandi Grade 9 Multi-Subject Study Tracker
-- Compatible with: Supabase PostgreSQL 15 / 16 / 17
-- Instructions: Copy and run this entire script in your Supabase SQL Editor.
-- It is designed to be 100% idempotent (safe to run multiple times).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 2. TABLES
-- ------------------------------------------------------------------------------

-- Table 1: canonical_syllabus
-- Stores the official syllabus units for Grade 9 subjects (1-level Main Units)
CREATE TABLE IF NOT EXISTS public.canonical_syllabus (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject TEXT NOT NULL,
  unit_number NUMERIC NOT NULL,
  unit_name TEXT NOT NULL,
  sub_lesson_code TEXT NOT NULL,
  sub_lesson_title TEXT NOT NULL,
  sort_order NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT canonical_syllabus_subject_code_key UNIQUE (subject, sub_lesson_code)
);

-- Table 2: tracker_progress
-- Tracks completion status (Lesson, Homework/Exercises, Papers done) per syllabus unit
CREATE TABLE IF NOT EXISTS public.tracker_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  syllabus_id UUID UNIQUE REFERENCES public.canonical_syllabus(id) ON DELETE CASCADE,
  subject TEXT,
  sub_lesson_code TEXT,
  lesson_done BOOLEAN DEFAULT FALSE,
  lesson_done_at TIMESTAMPTZ,
  lesson_days INTEGER DEFAULT 0,
  hw_done BOOLEAN DEFAULT FALSE,
  hw_done_at TIMESTAMPTZ,
  hw_days INTEGER DEFAULT 0,
  papers_done_count INTEGER DEFAULT 0,
  paper_days INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 3: unit_papers
-- Logs individual unit practice papers completed with scores
CREATE TABLE IF NOT EXISTS public.unit_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  syllabus_id UUID REFERENCES public.canonical_syllabus(id) ON DELETE SET NULL,
  subject TEXT NOT NULL,
  sub_lesson_code TEXT,
  paper_no NUMERIC NOT NULL,
  marks NUMERIC,
  logged_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 4: full_papers
-- Logs Term Test / Full Model examination papers and application config rows
CREATE TABLE IF NOT EXISTS public.full_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject TEXT NOT NULL,
  exam_date DATE,
  marks NUMERIC,
  time_taken TEXT,
  remarks TEXT,
  logged_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 5: spaced_repetition_log
-- Logs Ebbinghaus spaced repetition review stages (Day 1, 3, 7, 14, 30, 60, 90)
CREATE TABLE IF NOT EXISTS public.spaced_repetition_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  syllabus_id UUID REFERENCES public.canonical_syllabus(id) ON DELETE SET NULL,
  subject TEXT NOT NULL,
  sub_lesson_code TEXT,
  day_stage NUMERIC NOT NULL,
  cycle NUMERIC DEFAULT 1,
  completed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 6: study_timer_sessions
-- Logs focus timer sessions, manual sessions, and heatmap activity
CREATE TABLE IF NOT EXISTS public.study_timer_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject TEXT NOT NULL,
  unit_number NUMERIC,
  unit_name TEXT,
  timer_start_date DATE,
  timer_start_time TEXT,
  timer_stop_date DATE,
  timer_stop_time TEXT,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  duration_seconds NUMERIC DEFAULT 0,
  duration_minutes NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'completed',
  session_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. INDEXES FOR HIGH-PERFORMANCE QUERYING
-- ------------------------------------------------------------------------------

-- Indexes for canonical_syllabus
CREATE INDEX IF NOT EXISTS idx_canonical_syllabus_subj ON public.canonical_syllabus(subject);
CREATE INDEX IF NOT EXISTS idx_canonical_syllabus_sort ON public.canonical_syllabus(sort_order);

-- Indexes for tracker_progress
CREATE INDEX IF NOT EXISTS idx_tracker_progress_syl_id ON public.tracker_progress(syllabus_id);
CREATE INDEX IF NOT EXISTS idx_tracker_progress_subj ON public.tracker_progress(subject);
CREATE INDEX IF NOT EXISTS idx_tracker_progress_code ON public.tracker_progress(sub_lesson_code);

-- Indexes for unit_papers
CREATE INDEX IF NOT EXISTS idx_unit_papers_syl_id ON public.unit_papers(syllabus_id);
CREATE INDEX IF NOT EXISTS idx_unit_papers_subj ON public.unit_papers(subject);
CREATE INDEX IF NOT EXISTS idx_unit_papers_code ON public.unit_papers(sub_lesson_code);
CREATE INDEX IF NOT EXISTS idx_unit_papers_logged_at ON public.unit_papers(logged_at);

-- Indexes for full_papers
CREATE INDEX IF NOT EXISTS idx_full_papers_subj ON public.full_papers(subject);
CREATE INDEX IF NOT EXISTS idx_full_papers_exam_date ON public.full_papers(exam_date);
CREATE INDEX IF NOT EXISTS idx_full_papers_time_taken ON public.full_papers(time_taken);

-- Indexes for spaced_repetition_log
CREATE INDEX IF NOT EXISTS idx_sr_log_syl_id ON public.spaced_repetition_log(syllabus_id);
CREATE INDEX IF NOT EXISTS idx_sr_log_subj ON public.spaced_repetition_log(subject);
CREATE INDEX IF NOT EXISTS idx_sr_log_completed_at ON public.spaced_repetition_log(completed_at);

-- Indexes for study_timer_sessions
CREATE INDEX IF NOT EXISTS idx_timer_sessions_subj ON public.study_timer_sessions(subject);
CREATE INDEX IF NOT EXISTS idx_timer_sessions_date ON public.study_timer_sessions(session_date);
CREATE INDEX IF NOT EXISTS idx_timer_sessions_created ON public.study_timer_sessions(created_at);

-- ------------------------------------------------------------------------------
-- 4. TRIGGERS & AUTOMATION FUNCTIONS
-- ------------------------------------------------------------------------------

-- Helper function: auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_canonical_syllabus_updated_at ON public.canonical_syllabus;
CREATE TRIGGER trg_canonical_syllabus_updated_at
  BEFORE UPDATE ON public.canonical_syllabus
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_tracker_progress_updated_at ON public.tracker_progress;
CREATE TRIGGER trg_tracker_progress_updated_at
  BEFORE UPDATE ON public.tracker_progress
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_unit_papers_updated_at ON public.unit_papers;
CREATE TRIGGER trg_unit_papers_updated_at
  BEFORE UPDATE ON public.unit_papers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_full_papers_updated_at ON public.full_papers;
CREATE TRIGGER trg_full_papers_updated_at
  BEFORE UPDATE ON public.full_papers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger function: auto-sync subject & sub_lesson_code into tracker_progress
CREATE OR REPLACE FUNCTION public.sync_tracker_progress_meta()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.subject IS NULL OR NEW.sub_lesson_code IS NULL) AND NEW.syllabus_id IS NOT NULL THEN
    SELECT subject, sub_lesson_code 
    INTO NEW.subject, NEW.sub_lesson_code
    FROM public.canonical_syllabus       
    WHERE id = NEW.syllabus_id;   
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_tracker_progress_meta ON public.tracker_progress;
CREATE TRIGGER trg_sync_tracker_progress_meta
  BEFORE INSERT OR UPDATE ON public.tracker_progress
  FOR EACH ROW EXECUTE FUNCTION public.sync_tracker_progress_meta();

-- Trigger function: auto-create tracker_progress row whenever a new canonical_syllabus unit is added
CREATE OR REPLACE FUNCTION public.handle_canonical_syllabus_created()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.tracker_progress (syllabus_id, subject, sub_lesson_code, lesson_done, hw_done, papers_done_count)
  VALUES (NEW.id, NEW.subject, NEW.sub_lesson_code, false, false, 0)
  ON CONFLICT (syllabus_id) DO UPDATE
  SET subject = EXCLUDED.subject,
      sub_lesson_code = EXCLUDED.sub_lesson_code;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_canonical_syllabus_auto_progress ON public.canonical_syllabus;
CREATE TRIGGER trg_canonical_syllabus_auto_progress
  AFTER INSERT ON public.canonical_syllabus
  FOR EACH ROW EXECUTE FUNCTION public.handle_canonical_syllabus_created();

-- Routine function: recalculate days elapsed for urgent radar & review schedules
CREATE OR REPLACE FUNCTION public.recalculate_tracker_days()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.tracker_progress tp
    SET 
        lesson_days = CASE 
            WHEN tp.lesson_done AND tp.lesson_done_at IS NOT NULL 
            THEN GREATEST(0, (CURRENT_DATE - tp.lesson_done_at::DATE))
            ELSE 0 
        END,
        hw_days = CASE 
            WHEN tp.hw_done AND tp.hw_done_at IS NOT NULL 
            THEN GREATEST(0, (CURRENT_DATE - tp.hw_done_at::DATE))
            ELSE 0 
        END,
        paper_days = CASE 
            WHEN EXISTS (SELECT 1 FROM public.unit_papers up WHERE up.syllabus_id = tp.syllabus_id)
            THEN GREATEST(0, (CURRENT_DATE - (
                SELECT MAX(logged_at)::DATE 
                FROM public.unit_papers up 
                WHERE up.syllabus_id = tp.syllabus_id
            )))
            WHEN tp.hw_done AND tp.hw_done_at IS NOT NULL
            THEN GREATEST(0, (CURRENT_DATE - tp.hw_done_at::DATE))
            ELSE 0
        END,
        updated_at = NOW();
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) & PUBLIC POLICIES
-- ------------------------------------------------------------------------------

ALTER TABLE public.canonical_syllabus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracker_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unit_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.full_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spaced_repetition_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_timer_sessions ENABLE ROW LEVEL SECURITY;

-- Permissive public policies for seamless web client access (anon and authenticated)
DROP POLICY IF EXISTS "Allow anon full access on canonical_syllabus" ON public.canonical_syllabus;
CREATE POLICY "Allow anon full access on canonical_syllabus" ON public.canonical_syllabus
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon full access on tracker_progress" ON public.tracker_progress;
CREATE POLICY "Allow anon full access on tracker_progress" ON public.tracker_progress
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon full access on unit_papers" ON public.unit_papers;
CREATE POLICY "Allow anon full access on unit_papers" ON public.unit_papers
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon full access on full_papers" ON public.full_papers;
CREATE POLICY "Allow anon full access on full_papers" ON public.full_papers
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon full access on spaced_repetition_log" ON public.spaced_repetition_log;
CREATE POLICY "Allow anon full access on spaced_repetition_log" ON public.spaced_repetition_log
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon full access on study_timer_sessions" ON public.study_timer_sessions;
CREATE POLICY "Allow anon full access on study_timer_sessions" ON public.study_timer_sessions
  FOR ALL TO public USING (true) WITH CHECK (true);

-- ------------------------------------------------------------------------------
-- 6. SUPABASE REALTIME REPLICATION CONFIGURATION
-- ------------------------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.canonical_syllabus;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.tracker_progress;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.unit_papers;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.full_papers;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.spaced_repetition_log;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.study_timer_sessions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 7. BACKWARD COMPATIBILITY VIEWS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.study_sessions AS
SELECT * FROM public.study_timer_sessions;

CREATE OR REPLACE VIEW public.unit_paper AS
SELECT * FROM public.unit_papers;

-- ------------------------------------------------------------------------------
-- 8. POSTGRESQL RPC FUNCTION: get_dashboard_telemetry()
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_dashboard_telemetry()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  breakdown_obj jsonb := '{}'::jsonb;
  rec_subj record;
  subj_units jsonb;
  v_streak integer := 0;
  v_worked_today boolean := false;
  v_total_unit_papers integer := 0;
  v_total_full_papers integer := 0;
BEGIN
  -- 1. Total papers count
  SELECT COUNT(*) INTO v_total_unit_papers 
  FROM public.unit_papers;

  SELECT COUNT(*) INTO v_total_full_papers 
  FROM public.full_papers 
  WHERE time_taken NOT IN ('APP_CONFIG_PRINTED_PAPERS', 'APP_CONFIG_SUBJECTS');

  -- 2. Check if student worked today (logged any unit paper, full paper, or SR log today)
  SELECT EXISTS (
    SELECT 1 FROM (
      SELECT logged_at AS act_time FROM public.unit_papers WHERE logged_at IS NOT NULL
      UNION ALL
      SELECT COALESCE(exam_date::timestamptz, logged_at) AS act_time FROM public.full_papers WHERE time_taken NOT IN ('APP_CONFIG_PRINTED_PAPERS', 'APP_CONFIG_SUBJECTS')
      UNION ALL
      SELECT completed_at AS act_time FROM public.spaced_repetition_log WHERE completed_at IS NOT NULL
    ) acts
    WHERE acts.act_time::date = CURRENT_DATE
  ) INTO v_worked_today;

  -- 3. Calculate streak (consecutive calendar days of activity)
  WITH distinct_dates AS (
    SELECT DISTINCT act_date FROM (
      SELECT logged_at::date AS act_date FROM public.unit_papers WHERE logged_at IS NOT NULL
      UNION
      SELECT COALESCE(exam_date, logged_at::date) AS act_date FROM public.full_papers WHERE time_taken NOT IN ('APP_CONFIG_PRINTED_PAPERS', 'APP_CONFIG_SUBJECTS')
      UNION
      SELECT completed_at::date AS act_date FROM public.spaced_repetition_log WHERE completed_at IS NOT NULL
    ) d
    ORDER BY act_date DESC
  ),
  ranked AS (
    SELECT act_date, 
           (ROW_NUMBER() OVER (ORDER BY act_date DESC) - 1)::integer AS rn
    FROM distinct_dates
  ),
  streak_group AS (
    SELECT act_date, rn,
           (CASE WHEN v_worked_today THEN CURRENT_DATE - rn ELSE (CURRENT_DATE - 1) - rn END) AS expected_date
    FROM ranked
  )
  SELECT COUNT(*) INTO v_streak
  FROM streak_group
  WHERE act_date = expected_date;

  -- 4. Build breakdown per subject dynamically
  FOR rec_subj IN 
    SELECT DISTINCT subject 
    FROM public.canonical_syllabus 
    ORDER BY subject
  LOOP
    WITH unit_agg AS (
      SELECT 
        cs.unit_number,
        cs.unit_name,
        jsonb_agg(
          jsonb_build_object(
            'syllabusId', cs.id,
            'code', cs.sub_lesson_code,
            'title', cs.sub_lesson_title,
            'lessonDone', COALESCE(tp.lesson_done, false),
            'hwDone', COALESCE(tp.hw_done, false),
            'papersCount', COALESCE(tp.papers_done_count, 0)
          ) ORDER BY cs.sort_order, cs.sub_lesson_code
        ) AS sub_lessons,
        ROUND(
          AVG(
            (CASE WHEN COALESCE(tp.lesson_done, false) THEN 33.33 ELSE 0 END) +
            (CASE WHEN COALESCE(tp.hw_done, false) THEN 33.33 ELSE 0 END) +
            (CASE WHEN COALESCE(tp.papers_done_count, 0) > 0 THEN 33.34 ELSE 0 END)
          )
        ) AS unit_progress
      FROM public.canonical_syllabus cs
      LEFT JOIN public.tracker_progress tp ON cs.id = tp.syllabus_id
      WHERE cs.subject = rec_subj.subject
      GROUP BY cs.unit_number, cs.unit_name
      ORDER BY cs.unit_number
    )
    SELECT jsonb_agg(
      jsonb_build_object(
        'unitNumber', unit_number,
        'unitName', unit_name,
        'progress', unit_progress,
        'subLessons', sub_lessons
      )
    ) INTO subj_units
    FROM unit_agg;

    breakdown_obj := jsonb_set(breakdown_obj, ARRAY[rec_subj.subject], COALESCE(subj_units, '[]'::jsonb));
  END LOOP;

  result := jsonb_build_object(
    'breakdown', breakdown_obj,
    'streak', COALESCE(v_streak, 0),
    'workedToday', v_worked_today,
    'totalUnitPapersDone', v_total_unit_papers,
    'totalFullPapersDone', v_total_full_papers,
    'weeklyQuota', jsonb_build_object(
      'actual', '{}'::jsonb,
      'targets', '{}'::jsonb,
      'percentages', '{}'::jsonb
    )
  );

  RETURN result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. INITIAL CONFIGURATION SEED DATA
-- ------------------------------------------------------------------------------

-- Seed: Default printed papers state (empty JSON map)
INSERT INTO public.full_papers (subject, marks, time_taken, remarks, logged_at)
SELECT 'MATH', 0, 'APP_CONFIG_PRINTED_PAPERS', '{}', NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM public.full_papers WHERE time_taken = 'APP_CONFIG_PRINTED_PAPERS'
);

-- Seed: Default 13 Grade 9 subjects configuration
INSERT INTO public.full_papers (subject, marks, time_taken, remarks, logged_at)
SELECT 'MATH', 0, 'APP_CONFIG_SUBJECTS', '[
  {"code":"MATH","nameSi":"ගණිතය","nameEn":"Mathematics","color":"#0984e3","icon":"📐","active":true},
  {"code":"SCI","nameSi":"විද්‍යාව","nameEn":"Science","color":"#00b894","icon":"🔬","active":true},
  {"code":"SIN","nameSi":"සිංහල","nameEn":"Sinhala","color":"#e17055","icon":"📘","active":true},
  {"code":"ENG","nameSi":"ඉංග්‍රීසි","nameEn":"English","color":"#6c5ce7","icon":"🔤","active":true},
  {"code":"BUD","nameSi":"බුද්ධ ධර්මය","nameEn":"Buddhism","color":"#f39c12","icon":"☸️","active":true},
  {"code":"HIST","nameSi":"ඉතිහාසය","nameEn":"History","color":"#d35400","icon":"🏛️","active":true},
  {"code":"GEO","nameSi":"භූගෝල විද්‍යාව","nameEn":"Geography","color":"#27ae60","icon":"🌍","active":true},
  {"code":"CIV","nameSi":"පුරවැසි අධ්‍යාපනය","nameEn":"Civic Education","color":"#8e44ad","icon":"⚖️","active":true},
  {"code":"HLTH","nameSi":"සෞඛ්‍ය හා ශාරීරික අධ්‍යාපනය","nameEn":"Health & PE","color":"#e84393","icon":"🏃‍♀️","active":true},
  {"code":"ICT","nameSi":"තොරතුරු තාක්ෂණය","nameEn":"ICT","color":"#20bf6b","icon":"💻","active":true},
  {"code":"TAM","nameSi":"දෙමළ","nameEn":"Tamil","color":"#00cec9","icon":"🗣️","active":true},
  {"code":"AES","nameSi":"සෞන්දර්ය විෂය","nameEn":"Aesthetics","color":"#fd79a8","icon":"🎨","active":true},
  {"code":"PTS","nameSi":"ප්‍රායෝගික හා තාක්ෂණික කුසලතා","nameEn":"PTS","color":"#636e72","icon":"🛠️","active":true}
]', NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM public.full_papers WHERE time_taken = 'APP_CONFIG_SUBJECTS'
);

-- ------------------------------------------------------------------------------
-- 10. GRADE 9 CANONICAL SYLLABUS SEED DATA (13 SUBJECTS, 141 UNITS)
-- ------------------------------------------------------------------------------


-- Syllabus for: MATH (29 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('MATH', 1, 'ඒකකය 01: සංඛ්‍යා රටා', 'Unit 01', 'ඒකකය 01: සංඛ්‍යා රටා', 10),
  ('MATH', 2, 'ඒකකය 02: දර්ශක', 'Unit 02', 'ඒකකය 02: දර්ශක', 20),
  ('MATH', 3, 'ඒකකය 03: වටකුරු කිරීම සහ ඇස්තමේන්තු කිරීම', 'Unit 03', 'ඒකකය 03: වටකුරු කිරීම සහ ඇස්තමේන්තු කිරීම', 30),
  ('MATH', 4, 'ඒකකය 04: සංඛ්‍යා පාද', 'Unit 04', 'ඒකකය 04: සංඛ්‍යා පාද', 40),
  ('MATH', 5, 'ඒකකය 05: සුළු භාග', 'Unit 05', 'ඒකකය 05: සුළු භාග', 50),
  ('MATH', 6, 'ඒකකය 06: දශම', 'Unit 06', 'ඒකකය 06: දශම', 60),
  ('MATH', 7, 'ඒකකය 07: දිග මැනීම', 'Unit 07', 'ඒකකය 07: දිග මැනීම', 70),
  ('MATH', 8, 'ඒකකය 08: කෝණ', 'Unit 08', 'ඒකකය 08: කෝණ', 80),
  ('MATH', 9, 'ඒකකය 09: සරල රේඛීය තල රූප', 'Unit 09', 'ඒකකය 09: සරල රේඛීය තල රූප', 90),
  ('MATH', 10, 'ඒකකය 10: වීජීය ප්‍රකාශන', 'Unit 10', 'ඒකකය 10: වීජීය ප්‍රකාශන', 100),
  ('MATH', 11, 'ඒකකය 11: සාධක', 'Unit 11', 'ඒකකය 11: සාධක', 110),
  ('MATH', 12, 'ඒකකය 12: ස්කන්ධය', 'Unit 12', 'ඒකකය 12: ස්කන්ධය', 120),
  ('MATH', 13, 'ඒකකය 13: වේලාව', 'Unit 13', 'ඒකකය 13: වේලාව', 130),
  ('MATH', 14, 'ඒකකය 14: සමාන්තර රේඛා', 'Unit 14', 'ඒකකය 14: සමාන්තර රේඛා', 140),
  ('MATH', 15, 'ඒකකය 15: ද්විපද ප්‍රකාශන', 'Unit 15', 'ඒකකය 15: ද්විපද ප්‍රකාශන', 150),
  ('MATH', 16, 'ඒකකය 16: ද්‍රව ධාරිතාව', 'Unit 16', 'ඒකකය 16: ද්‍රව ධාරිතාව', 160),
  ('MATH', 17, 'ඒකකය 17: වර්ගඵලය', 'Unit 17', 'ඒකකය 17: වර්ගඵලය', 170),
  ('MATH', 18, 'ඒකකය 18: ප්‍රතිශත', 'Unit 18', 'ඒකකය 18: ප්‍රතිශත', 180),
  ('MATH', 19, 'ඒකකය 19: අනුපාත', 'Unit 19', 'ඒකකය 19: අනුපාත', 190),
  ('MATH', 20, 'ඒකකය 20: ත්‍රිකෝණ නිර්මාණ', 'Unit 20', 'ඒකකය 20: ත්‍රිකෝණ නිර්මාණ', 200),
  ('MATH', 21, 'ඒකකය 21: පරිමිතිය', 'Unit 21', 'ඒකකය 21: පරිමිතිය', 210),
  ('MATH', 22, 'ඒකකය 22: පරිමාව', 'Unit 22', 'ඒකකය 22: පරිමාව', 220),
  ('MATH', 23, 'ඒකකය 23: වීජීය අසමානතා', 'Unit 23', 'ඒකකය 23: වීජීය අසමානතා', 230),
  ('MATH', 24, 'ඒකකය 24: සරල සමීකරණ', 'Unit 24', 'ඒකකය 24: සරල සමීකරණ', 240),
  ('MATH', 25, 'ඒකකය 25: ඛණ්ඩාංක', 'Unit 25', 'ඒකකය 25: ඛණ්ඩාංක', 250),
  ('MATH', 26, 'ඒකකය 26: ප්‍රස්ථාර', 'Unit 26', 'ඒකකය 26: ප්‍රස්ථාර', 260),
  ('MATH', 27, 'ඒකකය 27: ජ්‍යාමිතික ඝනවස්තු', 'Unit 27', 'ඒකකය 27: ජ්‍යාමිතික ඝනවස්තු', 270),
  ('MATH', 28, 'ඒකකය 28: සම්භාවිතාව', 'Unit 28', 'ඒකකය 28: සම්භාවිතාව', 280),
  ('MATH', 29, 'ඒකකය 29: දත්ත නිරූපණය සහ අර්ථකථනය', 'Unit 29', 'ඒකකය 29: දත්ත නිරූපණය සහ අර්ථකථනය', 290)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: SCI (15 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('SCI', 1, 'ඒකකය 01: ජීවයේ පැවැත්ම හා රසායනික පදනම', 'Unit 01', 'ඒකකය 01: ජීවයේ පැවැත්ම හා රසායනික පදනම', 10),
  ('SCI', 2, 'ඒකකය 02: ශාක හා සත්ත්ව සෛල', 'Unit 02', 'ඒකකය 02: ශාක හා සත්ත්ව සෛල', 20),
  ('SCI', 3, 'ඒකකය 03: පදාර්ථයේ ව්‍යුහය', 'Unit 03', 'ඒකකය 03: පදාර්ථයේ ව්‍යුහය', 30),
  ('SCI', 4, 'ඒකකය 04: මූලද්‍රව්‍ය හා සංයෝග', 'Unit 04', 'ඒකකය 04: මූලද්‍රව්‍ය හා සංයෝග', 40),
  ('SCI', 5, 'ඒකකය 05: බලය හා එහි ක්‍රියා', 'Unit 05', 'ඒකකය 05: බලය හා එහි ක්‍රියා', 50),
  ('SCI', 6, 'ඒකකය 06: ශක්ති ප්‍රභව හා භාවිතය', 'Unit 06', 'ඒකකය 06: ශක්ති ප්‍රභව හා භාවිතය', 60),
  ('SCI', 7, 'ඒකකය 07: තාපය හා උෂ්ණත්වය', 'Unit 07', 'ඒකකය 07: තාපය හා උෂ්ණත්වය', 70),
  ('SCI', 8, 'ඒකකය 08: ආලෝකය හා දෘෂ්ටිය', 'Unit 08', 'ඒකකය 08: ආලෝකය හා දෘෂ්ටිය', 80),
  ('SCI', 9, 'ඒකකය 09: තරංග හා ඒවායේ යෙදීම්', 'Unit 09', 'ඒකකය 09: තරංග හා ඒවායේ යෙදීම්', 90),
  ('SCI', 10, 'ඒකකය 10: ශබ්දය සහ ශ්‍රවණය', 'Unit 10', 'ඒකකය 10: ශබ්දය සහ ශ්‍රවණය', 100),
  ('SCI', 11, 'ඒකකය 11: විද්‍යුත් ධාරාවේ රසායනික ඵල', 'Unit 11', 'ඒකකය 11: විද්‍යුත් ධාරාවේ රසායනික ඵල', 110),
  ('SCI', 12, 'ඒකකය 12: චුම්බක හා විද්‍යුත් චුම්බක', 'Unit 12', 'ඒකකය 12: චුම්බක හා විද්‍යුත් චුම්බක', 120),
  ('SCI', 13, 'ඒකකය 13: ශ්‍රී ලංකාවේ ඛනිජ සම්පත්', 'Unit 13', 'ඒකකය 13: ශ්‍රී ලංකාවේ ඛනිජ සම්පත්', 130),
  ('SCI', 14, 'ඒකකය 14: ජෛවගෝලය හා පාරිසරික සමතුලිතතාව', 'Unit 14', 'ඒකකය 14: ජෛවගෝලය හා පාරිසරික සමතුලිතතාව', 140),
  ('SCI', 15, 'ඒකකය 15: මිනිස් සිරුරේ පද්ධති හා සෞඛ්‍යය', 'Unit 15', 'ඒකකය 15: මිනිස් සිරුරේ පද්ධති හා සෞඛ්‍යය', 150)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: SIN (12 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('SIN', 1, 'ඒකකය 01: සිංහල හෝඩිය හා අක්ෂර වින්‍යාසය', 'Unit 01', 'ඒකකය 01: සිංහල හෝඩිය හා අක්ෂර වින්‍යාසය', 10),
  ('SIN', 2, 'ඒකකය 02: නාම පද, ක්‍රියා පද හා විභක්ති', 'Unit 02', 'ඒකකය 02: නාම පද, ක්‍රියා පද හා විභක්ති', 20),
  ('SIN', 3, 'ඒකකය 03: වාක්‍ය රටා හා ආඛ්‍යාත රීති', 'Unit 03', 'ඒකකය 03: වාක්‍ය රටා හා ආඛ්‍යාත රීති', 30),
  ('SIN', 4, 'ඒකකය 04: විරාම ලක්ෂණ භාවිතය', 'Unit 04', 'ඒකකය 04: විරාම ලක්ෂණ භාවිතය', 40),
  ('SIN', 5, 'ඒකකය 05: සමාස හා තද්ධිත පද', 'Unit 05', 'ඒකකය 05: සමාස හා තද්ධිත පද', 50),
  ('SIN', 6, 'ඒකකය 06: පද්‍ය සාහිත්‍ය රසවින්දනය', 'Unit 06', 'ඒකකය 06: පද්‍ය සාහිත්‍ය රසවින්දනය', 60),
  ('SIN', 7, 'ඒකකය 07: ගද්‍ය සාහිත්‍ය රසවින්දනය', 'Unit 07', 'ඒකකය 07: ගද්‍ය සාහිත්‍ය රසවින්දනය', 70),
  ('SIN', 8, 'ඒකකය 08: කෙටිකතා හා නාට්‍ය රසවින්දනය', 'Unit 08', 'ඒකකය 08: කෙටිකතා හා නාට්‍ය රසවින්දනය', 80),
  ('SIN', 9, 'ඒකකය 09: නිබන්ධන හා නිල ලිපි රචනය', 'Unit 09', 'ඒකකය 09: නිබන්ධන හා නිල ලිපි රචනය', 90),
  ('SIN', 10, 'ඒකකය 10: සාරාංශකරණය හා අවබෝධය', 'Unit 10', 'ඒකකය 10: සාරාංශකරණය හා අවබෝධය', 100),
  ('SIN', 11, 'ඒකකය 11: ප්‍රස්ථාව පිරුළු හා රූඪි', 'Unit 11', 'ඒකකය 11: ප්‍රස්ථාව පිරුළු හා රූඪි', 110),
  ('SIN', 12, 'ඒකකය 12: පුවත්පත් වාර්තා හා නිවේදන', 'Unit 12', 'ඒකකය 12: පුවත්පත් වාර්තා හා නිවේදන', 120)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: ENG (10 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('ENG', 1, 'Unit 01: Friends and Social Interactions', 'Unit 01', 'Unit 01: Friends and Social Interactions', 10),
  ('ENG', 2, 'Unit 02: Nature, Environment and Conservation', 'Unit 02', 'Unit 02: Nature, Environment and Conservation', 20),
  ('ENG', 3, 'Unit 03: Health, Nutrition and Hygiene', 'Unit 03', 'Unit 03: Health, Nutrition and Hygiene', 30),
  ('ENG', 4, 'Unit 04: Heroes and Role Models', 'Unit 04', 'Unit 04: Heroes and Role Models', 40),
  ('ENG', 5, 'Unit 05: Science and Modern Technology', 'Unit 05', 'Unit 05: Science and Modern Technology', 50),
  ('ENG', 6, 'Unit 06: Travel, Tourism and World Wonders', 'Unit 06', 'Unit 06: Travel, Tourism and World Wonders', 60),
  ('ENG', 7, 'Unit 07: Culture, Traditions and Heritage', 'Unit 07', 'Unit 07: Culture, Traditions and Heritage', 70),
  ('ENG', 8, 'Unit 08: Sports, Fitness and Leisure', 'Unit 08', 'Unit 08: Sports, Fitness and Leisure', 80),
  ('ENG', 9, 'Unit 09: Mass Media and Communication', 'Unit 09', 'Unit 09: Mass Media and Communication', 90),
  ('ENG', 10, 'Unit 10: Careers, Future Goals and Aspirations', 'Unit 10', 'Unit 10: Careers, Future Goals and Aspirations', 100)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: BUD (10 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('BUD', 1, 'ඒකකය 01: තෙරුවන් සරණ හා බුද්ධ චරිතය', 'Unit 01', 'ඒකකය 01: තෙරුවන් සරණ හා බුද්ධ චරිතය', 10),
  ('BUD', 2, 'ඒකකය 02: ධම්මපදය හා ආදර්ශවත් ගාථා', 'Unit 02', 'ඒකකය 02: ධම්මපදය හා ආදර්ශවත් ගාථා', 20),
  ('BUD', 3, 'ඒකකය 03: චතුරාර්ය සත්‍යය ධර්මය', 'Unit 03', 'ඒකකය 03: චතුරාර්ය සත්‍යය ධර්මය', 30),
  ('BUD', 4, 'ඒකකය 04: ත්‍රිලක්ෂණය හා කර්ම න්‍යාය', 'Unit 04', 'ඒකකය 04: ත්‍රිලක්ෂණය හා කර්ම න්‍යාය', 40),
  ('BUD', 5, 'ඒකකය 05: පංචසීලය හා සාමාජික විනය', 'Unit 05', 'ඒකකය 05: පංචසීලය හා සාමාජික විනය', 50),
  ('BUD', 6, 'ඒකකය 06: ශ්‍රී ලාංකේය ශාසන ඉතිහාසය', 'Unit 06', 'ඒකකය 06: ශ්‍රී ලාංකේය ශාසන ඉතිහාසය', 60),
  ('BUD', 7, 'ඒකකය 07: මහා මංගල සූත්‍රය', 'Unit 07', 'ඒකකය 07: මහා මංගල සූත්‍රය', 70),
  ('BUD', 8, 'ඒකකය 08: පරාභව හා වසල සූත්‍ර', 'Unit 08', 'ඒකකය 08: පරාභව හා වසල සූත්‍ර', 80),
  ('BUD', 9, 'ඒකකය 09: බෞද්ධ සාරධර්ම හා සමාජ සුභසාධනය', 'Unit 09', 'ඒකකය 09: බෞද්ධ සාරධර්ම හා සමාජ සුභසාධනය', 90),
  ('BUD', 10, 'ඒකකය 10: බෞද්ධ පරිසර දර්ශනය', 'Unit 10', 'ඒකකය 10: බෞද්ධ පරිසර දර්ශනය', 100)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: HIST (9 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('HIST', 1, 'ඒකකය 01: ශ්‍රී ලංකාවේ ප්‍රාග් ඓතිහාසික යුගය', 'Unit 01', 'ඒකකය 01: ශ්‍රී ලංකාවේ ප්‍රාග් ඓතිහාසික යුගය', 10),
  ('HIST', 2, 'ඒකකය 02: අනුරාධපුර රාජධානියේ නැගීම හා ජල ශිෂ්ටාචාරය', 'Unit 02', 'ඒකකය 02: අනුරාධපුර රාජධානියේ නැගීම හා ජල ශිෂ්ටාචාරය', 20),
  ('HIST', 3, 'ඒකකය 03: පොළොන්නරු යුගය හා එහි විශිෂ්ටත්වය', 'Unit 03', 'ඒකකය 03: පොළොන්නරු යුගය හා එහි විශිෂ්ටත්වය', 30),
  ('HIST', 4, 'ඒකකය 04: බිඳවැටීම හා නිරිතදිග රාජධානි', 'Unit 04', 'ඒකකය 04: බිඳවැටීම හා නිරිතදිග රාජධානි', 40),
  ('HIST', 5, 'ඒකකය 05: කෝට්ටේ හා සීතාවක රාජධානි', 'Unit 05', 'ඒකකය 05: කෝට්ටේ හා සීතාවක රාජධානි', 50),
  ('HIST', 6, 'ඒකකය 06: උඩරට රාජධානිය හා විදේශ ආක්‍රමණ', 'Unit 06', 'ඒකකය 06: උඩරට රාජධානිය හා විදේශ ආක්‍රමණ', 60),
  ('HIST', 7, 'ඒකකය 07: යුරෝපීය බලපෑම: පෘතුගීසි හා ලන්දේසි පාලනය', 'Unit 07', 'ඒකකය 07: යුරෝපීය බලපෑම: පෘතුගීසි හා ලන්දේසි පාලනය', 70),
  ('HIST', 8, 'ඒකකය 08: බ්‍රිතාන්‍ය පාලනය හා නිදහස් අරගල', 'Unit 08', 'ඒකකය 08: බ්‍රිතාන්‍ය පාලනය හා නිදහස් අරගල', 80),
  ('HIST', 9, 'ඒකකය 09: ලෝක ඉතිහාසය: පුනරුදය හා කාර්මික විප්ලවය', 'Unit 09', 'ඒකකය 09: ලෝක ඉතිහාසය: පුනරුදය හා කාර්මික විප්ලවය', 90)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: GEO (8 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('GEO', 1, 'ඒකකය 01: පෘථිවියේ පිහිටීම හා දිශා හඳුනාගැනීම', 'Unit 01', 'ඒකකය 01: පෘථිවියේ පිහිටීම හා දිශා හඳුනාගැනීම', 10),
  ('GEO', 2, 'ඒකකය 02: සිතියම් කියවීම හා පරිමාණය', 'Unit 02', 'ඒකකය 02: සිතියම් කියවීම හා පරිමාණය', 20),
  ('GEO', 3, 'ඒකකය 03: ශ්‍රී ලංකාවේ භූ රූප හා උන්නතාංශ', 'Unit 03', 'ඒකකය 03: ශ්‍රී ලංකාවේ භූ රූප හා උන්නතාංශ', 30),
  ('GEO', 4, 'ඒකකය 04: කාලගුණය, දේශගුණය හා මෝසම් සුළං', 'Unit 04', 'ඒකකය 04: කාලගුණය, දේශගුණය හා මෝසම් සුළං', 40),
  ('GEO', 5, 'ඒකකය 05: ශ්‍රී ලංකාවේ ස්වාභාවික සම්පත් හා ජල පද්ධති', 'Unit 05', 'ඒකකය 05: ශ්‍රී ලංකාවේ ස්වාභාවික සම්පත් හා ජල පද්ධති', 50),
  ('GEO', 6, 'ඒකකය 06: කෘෂිකර්මාන්තය හා ධීවර කර්මාන්තය', 'Unit 06', 'ඒකකය 06: කෘෂිකර්මාන්තය හා ධීවර කර්මාන්තය', 60),
  ('GEO', 7, 'ඒකකය 07: ලෝකයේ ප්‍රධාන දේශගුණික කලාප', 'Unit 07', 'ඒකකය 07: ලෝකයේ ප්‍රධාන දේශගුණික කලාප', 70),
  ('GEO', 8, 'ඒකකය 08: ස්වාභාවික ආපදා හා ආපදා කළමනාකරණය', 'Unit 08', 'ඒකකය 08: ස්වාභාවික ආපදා හා ආපදා කළමනාකරණය', 80)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: CIV (8 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('CIV', 1, 'ඒකකය 01: ප්‍රජාතන්ත්‍රවාදය හා යහපාලනයේ ලක්ෂණ', 'Unit 01', 'ඒකකය 01: ප්‍රජාතන්ත්‍රවාදය හා යහපාලනයේ ලක්ෂණ', 10),
  ('CIV', 2, 'ඒකකය 02: ආණ්ඩුක්‍රම ව්‍යවස්ථාව සහ රජයේ ප්‍රධාන අංග', 'Unit 02', 'ඒකකය 02: ආණ්ඩුක්‍රම ව්‍යවස්ථාව සහ රජයේ ප්‍රධාන අංග', 20),
  ('CIV', 3, 'ඒකකය 03: මූලික මිනිස් අයිතිවාසිකම් හා පුරවැසි යුතුකම්', 'Unit 03', 'ඒකකය 03: මූලික මිනිස් අයිතිවාසිකම් හා පුරවැසි යුතුකම්', 30),
  ('CIV', 4, 'ඒකකය 04: නීතියේ ආධිපත්‍යය හා අධිකරණ පද්ධතිය', 'Unit 04', 'ඒකකය 04: නීතියේ ආධිපත්‍යය හා අධිකරණ පද්ධතිය', 40),
  ('CIV', 5, 'ඒකකය 05: බහුසංස්කෘතික සමාජය හා ජාතික සංහිඳියාව', 'Unit 05', 'ඒකකය 05: බහුසංස්කෘතික සමාජය හා ජාතික සංහිඳියාව', 50),
  ('CIV', 6, 'ඒකකය 06: සාමකාමී ගැටුම් නිරාකරණය', 'Unit 06', 'ඒකකය 06: සාමකාමී ගැටුම් නිරාකරණය', 60),
  ('CIV', 7, 'ඒකකය 07: පළාත් පාලන ආයතන හා ප්‍රජා සේවාවන්', 'Unit 07', 'ඒකකය 07: පළාත් පාලන ආයතන හා ප්‍රජා සේවාවන්', 70),
  ('CIV', 8, 'ඒකකය 08: ජාත්‍යන්තර සංවිධාන හා එක්සත් ජාතීන්ගේ සංවිධානය', 'Unit 08', 'ඒකකය 08: ජාත්‍යන්තර සංවිධාන හා එක්සත් ජාතීන්ගේ සංවිධානය', 80)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: HLTH (8 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('HLTH', 1, 'ඒකකය 01: නව යොවුන් වියේ ශාරීරික හා මානසික සංවර්ධනය', 'Unit 01', 'ඒකකය 01: නව යොවුන් වියේ ශාරීරික හා මානසික සංවර්ධනය', 10),
  ('HLTH', 2, 'ඒකකය 02: සමබල ආහාර රටාව හා පෝෂණ ඌනතා', 'Unit 02', 'ඒකකය 02: සමබල ආහාර රටාව හා පෝෂණ ඌනතා', 20),
  ('HLTH', 3, 'ඒකකය 03: බෝවන හා බෝනොවන රෝග වැළැක්වීම', 'Unit 03', 'ඒකකය 03: බෝවන හා බෝනොවන රෝග වැළැක්වීම', 30),
  ('HLTH', 4, 'ඒකකය 04: මානසික සුවතාව හා ආතති පාලනය', 'Unit 04', 'ඒකකය 04: මානසික සුවතාව හා ආතති පාලනය', 40),
  ('HLTH', 5, 'ඒකකය 05: මලල ක්‍රීඩා කුසලතා හා නීති රීති', 'Unit 05', 'ඒකකය 05: මලල ක්‍රීඩා කුසලතා හා නීති රීති', 50),
  ('HLTH', 6, 'ඒකකය 06: සංවිධානාත්මක කණ්ඩායම් ක්‍රීඩා', 'Unit 06', 'ඒකකය 06: සංවිධානාත්මක කණ්ඩායම් ක්‍රීඩා', 60),
  ('HLTH', 7, 'ඒකකය 07: ප්‍රථමාධාර හා අනතුරු වැළැක්වීම', 'Unit 07', 'ඒකකය 07: ප්‍රථමාධාර හා අනතුරු වැළැක්වීම', 70),
  ('HLTH', 8, 'ඒකකය 08: ශාරීරික යෝග්‍යතාව හා ක්‍රියාශීලී දිවිපෙවෙත', 'Unit 08', 'ඒකකය 08: ශාරීරික යෝග්‍යතාව හා ක්‍රියාශීලී දිවිපෙවෙත', 80)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: ICT (10 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('ICT', 1, 'ඒකකය 01: තොරතුරු හා සන්නිවේදන තාක්ෂණයේ මූලික සංකල්ප', 'Unit 01', 'ඒකකය 01: තොරතුරු හා සන්නිවේදන තාක්ෂණයේ මූලික සංකල්ප', 10),
  ('ICT', 2, 'ඒකකය 02: පරිගණක දෘඩාංග සහ උපාංග', 'Unit 02', 'ඒකකය 02: පරිගණක දෘඩාංග සහ උපාංග', 20),
  ('ICT', 3, 'ඒකකය 03: මෙහෙයුම් පද්ධති හා ගොනු කළමනාකරණය', 'Unit 03', 'ඒකකය 03: මෙහෙයුම් පද්ධති හා ගොනු කළමනාකරණය', 30),
  ('ICT', 4, 'ඒකකය 04: වදන් සැකසුම් මෘදුකාංග', 'Unit 04', 'ඒකකය 04: වදන් සැකසුම් මෘදුකාංග', 40),
  ('ICT', 5, 'ඒකකය 05: පැතුරුම්පත් මෘදුකාංග', 'Unit 05', 'ඒකකය 05: පැතුරුම්පත් මෘදුකාංග', 50),
  ('ICT', 6, 'ඒකකය 06: ඉදිරිපත් කිරීමේ මෘදුකාංග', 'Unit 06', 'ඒකකය 06: ඉදිරිපත් කිරීමේ මෘදුකාංග', 60),
  ('ICT', 7, 'ඒකකය 07: අන්තර්ජාලය, විද්‍යුත් තැපෑල හා වෙබ් ගවේෂණය', 'Unit 07', 'ඒකකය 07: අන්තර්ජාලය, විද්‍යුත් තැපෑල හා වෙබ් ගවේෂණය', 70),
  ('ICT', 8, 'ඒකකය 08: ගැටලු විසඳීම, ඇල්ගොරිතම සහ ගැලීම් සටහන්', 'Unit 08', 'ඒකකය 08: ගැටලු විසඳීම, ඇල්ගොරිතම සහ ගැලීම් සටහන්', 80),
  ('ICT', 9, 'ඒකකය 09: දෘශ්‍ය ක්‍රමලේඛනය', 'Unit 09', 'ඒකකය 09: දෘශ්‍ය ක්‍රමලේඛනය', 90),
  ('ICT', 10, 'ඒකකය 10: සයිබර් ආරක්ෂාව හා තොරතුරු තාක්ෂණ ආචාර ධර්ම', 'Unit 10', 'ඒකකය 10: සයිබර් ආරක්ෂාව හා තොරතුරු තාක්ෂණ ආචාර ධර්ම', 100)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: TAM (8 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('TAM', 1, 'ඒකකය 01: දෙමළ හෝඩිය, අක්ෂර හා උච්චාරණය', 'Unit 01', 'ඒකකය 01: දෙමළ හෝඩිය, අක්ෂර හා උච්චාරණය', 10),
  ('TAM', 2, 'ඒකකය 02: එදිනෙදා භාවිත නාම පද හා වචන මාලාව', 'Unit 02', 'ඒකකය 02: එදිනෙදා භාවිත නාම පද හා වචන මාලාව', 20),
  ('TAM', 3, 'ඒකකය 03: ආචාර සමාචාර හා සරල සංවාද', 'Unit 03', 'ඒකකය 03: ආචාර සමාචාර හා සරල සංවාද', 30),
  ('TAM', 4, 'ඒකකය 04: සරල වාක්‍ය රටා හා ක්‍රියා පද', 'Unit 04', 'ඒකකය 04: සරල වාක්‍ය රටා හා ක්‍රියා පද', 40),
  ('TAM', 5, 'ඒකකය 05: කාල භේදය: අතීත, වර්තමාන හා අනාගත', 'Unit 05', 'ඒකකය 05: කාල භේදය: අතීත, වර්තමාන හා අනාගත', 50),
  ('TAM', 6, 'ඒකකය 06: සරල ඡේද කියවීම හා තේරුම් ගැනීම', 'Unit 06', 'ඒකකය 06: සරල ඡේද කියවීම හා තේරුම් ගැනීම', 60),
  ('TAM', 7, 'ඒකකය 07: සරල ලිපි හා කෙටි සටහන් ලිවීම', 'Unit 07', 'ඒකකය 07: සරල ලිපි හා කෙටි සටහන් ලිවීම', 70),
  ('TAM', 8, 'ඒකකය 08: විවිධ අවස්ථා ආශ්‍රිත දෙබස් හා සන්නිවේදනය', 'Unit 08', 'ඒකකය 08: විවිධ අවස්ථා ආශ්‍රිත දෙබස් හා සන්නිවේදනය', 80)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: AES (6 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('AES', 1, 'ඒකකය 01: සෞන්දර්ය කලා නිර්මාණ මූලධර්ම', 'Unit 01', 'ඒකකය 01: සෞන්දර්ය කලා නිර්මාණ මූලධර්ම', 10),
  ('AES', 2, 'ඒකකය 02: ශ්‍රී ලාංකේය සාම්ප්‍රදායික කලා උරුමය', 'Unit 02', 'ඒකකය 02: ශ්‍රී ලාංකේය සාම්ප්‍රදායික කලා උරුමය', 20),
  ('AES', 3, 'ඒකකය 03: රේඛා, වර්ණ, හැඩතල හා සංයුතිය', 'Unit 03', 'ඒකකය 03: රේඛා, වර්ණ, හැඩතල හා සංයුතිය', 30),
  ('AES', 4, 'ඒකකය 04: පෙරදිග හා බටහිර කලා නිර්මාණ ශිල්පීය ක්‍රම', 'Unit 04', 'ඒකකය 04: පෙරදිග හා බටහිර කලා නිර්මාණ ශිල්පීය ක්‍රම', 40),
  ('AES', 5, 'ඒකකය 05: ස්වභාව ධර්මය සහ පාරිසරික නිර්මාණ', 'Unit 05', 'ඒකකය 05: ස්වභාව ධර්මය සහ පාරිසරික නිර්මාණ', 50),
  ('AES', 6, 'ඒකකය 06: නිර්මාණාත්මක ප්‍රකාශනය හා කලා ප්‍රදර්ශනය', 'Unit 06', 'ඒකකය 06: නිර්මාණාත්මක ප්‍රකාශනය හා කලා ප්‍රදර්ශනය', 60)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Syllabus for: PTS (8 units)
INSERT INTO public.canonical_syllabus (subject, unit_number, unit_name, sub_lesson_code, sub_lesson_title, sort_order)
VALUES
  ('PTS', 1, 'ඒකකය 01: වැඩබිම් ආරක්ෂාව සහ අත් ආයුධ භාවිතය', 'Unit 01', 'ඒකකය 01: වැඩබිම් ආරක්ෂාව සහ අත් ආයුධ භාවිතය', 10),
  ('PTS', 2, 'ඒකකය 02: මූලික තාක්ෂණික ඇඳීම සහ සැලසුම්කරණය', 'Unit 02', 'ඒකකය 02: මූලික තාක්ෂණික ඇඳීම සහ සැලසුම්කරණය', 20),
  ('PTS', 3, 'ඒකකය 03: දැව හා ලෝහ නිර්මාණ තාක්ෂණය', 'Unit 03', 'ඒකකය 03: දැව හා ලෝහ නිර්මාණ තාක්ෂණය', 30),
  ('PTS', 4, 'ඒකකය 04: සරල ගෘහස්ථ විදුලි පරිපථ හා රැහැන් ඇදීම', 'Unit 04', 'ඒකකය 04: සරල ගෘහස්ථ විදුලි පරිපථ හා රැහැන් ඇදීම', 40),
  ('PTS', 5, 'ඒකකය 05: මූලික ඉලෙක්ට්‍රොනික උපාංග සහ යෙදීම්', 'Unit 05', 'ඒකකය 05: මූලික ඉලෙක්ට්‍රොනික උපාංග සහ යෙදීම්', 50),
  ('PTS', 6, 'ඒකකය 06: ආහාර තාක්ෂණය සහ කල්තබා ගැනීමේ ක්‍රම', 'Unit 06', 'ඒකකය 06: ආහාර තාක්ෂණය සහ කල්තබා ගැනීමේ ක්‍රම', 60),
  ('PTS', 7, 'ඒකකය 07: කෘෂිකාර්මික ශිල්පීය ක්‍රම සහ ශාක ප්‍රචාරණය', 'Unit 07', 'ඒකකය 07: කෘෂිකාර්මික ශිල්පීය ක්‍රම සහ ශාක ප්‍රචාරණය', 70),
  ('PTS', 8, 'ඒකකය 08: සරල නිපැයුම් හා ව්‍යවසායකත්ව ව්‍යාපෘති', 'Unit 08', 'ඒකකය 08: සරල නිපැයුම් හා ව්‍යවසායකත්ව ව්‍යාපෘති', 80)
ON CONFLICT (subject, sub_lesson_code) DO UPDATE
SET unit_name = EXCLUDED.unit_name,
    sub_lesson_title = EXCLUDED.sub_lesson_title,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- ------------------------------------------------------------------------------
-- 11. INITIALIZE TRACKER PROGRESS FOR ALL UNITS
-- ------------------------------------------------------------------------------
-- Ensures all 141 syllabus rows have an initialized tracker_progress entry
INSERT INTO public.tracker_progress (syllabus_id, subject, sub_lesson_code, lesson_done, hw_done, papers_done_count)
SELECT id, subject, sub_lesson_code, false, false, 0
FROM public.canonical_syllabus
ON CONFLICT (syllabus_id) DO NOTHING;

-- ==============================================================================
-- END OF COMPLETE GRADE 9 SCHEMA SCRIPT
-- ==============================================================================
