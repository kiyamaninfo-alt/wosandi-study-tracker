# Wosandi Grade 9 Study Tracker (krishsoft) - AGY / Gemini Rules
Stack: Standalone Multi-Page HTML5 / Vanilla JS / CSS3 PWA (`index.html`, `sidebar.html`, `study-analytics.html`, `sw.js`, `server.js`) + Supabase + Chart.js

## 1. Core Architecture & File Roles:
- **DO NOT convert to React/Vite**: Preserve the existing standalone HTML/CSS/JS PWA architecture (`index.html`, `sidebar.html`, `study-analytics.html`, `sw.js`).
- **Keep Existing Supabase Env/Config Untouched**: Do not delete or break existing Supabase client initialization; the user will swap `.env` and URLs later.
- **Security PIN**: Maintain password `3408` for all protected write/edit actions.

## 2. Grade 9 Domain Rules (Dynamic Subjects & NO Sub-Units):
- **Dynamic Multi-Subject Engine (Up to 13+ Subjects)**:
  - Never hardcode only `ICT`, `ET`, `SFT`.
  - Use a dynamic subject configuration (`getActiveSubjects()`) stored in `localStorage` (`g9_subjects_config`) and synced with Supabase, with sensible Grade 9 defaults (Mathematics, Science, Sinhala, English, Buddhism, History, Geography, Civic Ed, Health, ICT, Tamil, Aesthetics, PTS).
  - Each subject has `{ code, nameSi, nameEn, color, icon, active }`.
  - Allow adding, editing, enabling/disabling subjects via `sidebar.html` (protected by PIN `3408`).
- **Strict 1-Level Unit Hierarchy (NO SUB-UNITS)**:
  - Completely remove the Sub-Units layer (`1.1`, `1.2`). Every subject consists strictly of **Main Units** (`unit_number`: 1, 2, 3... and `unit_name`: "ඒකකය 01: ...").
  - For backward-compatible database storage in `canonical_syllabus`, automatically set `sub_lesson_code = "Unit " + unit_number` and `sub_lesson_title = unit_name`.
  - Lesson Done (`lesson_done`), Homework/Study Done (`hw_done`), Unit Paper logging, Print tracking, Urgent Radar, and Ebbinghaus Spaced Repetition operate directly on **Main Units**.
- **2-Tier Paper System**:
  - Merge "Sub-Unit Paper" and "Full Unit Paper" into a single **"Unit Paper (පාඩම් ප්‍රශ්න පත්‍ර)"** workflow.
  - Keep **"Full / Term Paper (වාර විභාග / සම්පූර්ණ ප්‍රශ්න පත්‍ර)"** as the second tier. Replace A/L Z-Score with **Overall Average %** across all active subjects.
- **User-Configurable Countdown**:
  - Allow the user to customize the Countdown Target Date/Time and Target Title/Header inside the Settings Modal (`localStorage` key: `g9_countdown_config`).

## 3. Token Optimization & Surgical Editing Rules:
- **Large File Handling (`index.html` is ~747KB)**: NEVER rewrite or output the entire file. Always inspect specific line ranges or function names and apply **surgical diffs** only to the targeted sections.
- **Preserve All Premium Features**: Keep Dark/Light/System themes, Font Scale slider, Sinhala/English toggle, Deep Focus Timer (Brown Noise, Wake Lock, Target Picker), Offline IndexedDB Sync Queue, Activity Log & Undo, and A4 PDF Export.
