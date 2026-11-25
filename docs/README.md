# SelectYours docs

Reference material for the project.

For what the project is and how to rebuild the website, see the [main README](../README.md). The research and sourcing rules for school profiles are in [universities/README.md](universities/README.md).

| File | What it is |
| --- | --- |
| [us-full-need-schools-international.md](us-full-need-schools-international.md) | The verified list. US colleges that meet 100% of demonstrated need for international first-year bachelor's students, grouped need-blind / need-aware / special / partial / excluded, with conditions and official sources. |
| [us-full-need-schools-international.csv](us-full-need-schools-international.csv) | The same research as data: 99 schools checked, one row each, including those that don't qualify. |
| [lebeau-list-audit.md](lebeau-list-audit.md) | School-by-school check of William LeBeau's 71-school "Schools That Pay" list: what's right, wrong and missing. |
| [methodology-prestige-difficulty.md](methodology-prestige-difficulty.md) | How the Prestige Index and the Difficulty Index are built (version 1.1), with sources. |
| [prestige-and-difficulty-ranking.md](prestige-and-difficulty-ranking.md) | **The ranking.** All 62 full-need schools ranked by prestige and by difficulty, with tiers and sub-scores. |
| [university-metrics.csv](university-metrics.csv) | Every index input and score in one table, for the website. |
| [universities/](universities/README.md) | One profile per school (`<slug>.md`), plus machine-readable data in `universities/_data/`. |

The indexes are recomputed with `tools/compute-indexes.ps1`. It reads `universities/_data/`, then rewrites the ranking file, the CSV and each profile's AUTO blocks.

Research last verified: **22 November 2026** for the full-need list, and **23 November 2026** for the school profiles (Fall 2027 entry cycle). Aid policies change every year, so re-check a school's official page before relying on it.

## CSV columns

| Column | Values |
| --- | --- |
| `school`, `state`, `institution_type` | Official name, US state, kind of institution |
| `awards_bachelors` | `yes` / `no` (only Deep Springs is `no`) |
| `meets_full_need_intl` | `yes` / `partial` / `unclear` / `no` |
| `category` | `A_need_blind_full_need`, `B_need_aware_full_need`, `C_special_model`, `D_partial_limited_unclear`, `E_not_full_need` |
| `admission_policy_intl` | Need-blind, Need-aware, Need-sensitive, Not need-blind, or Not stated |
| `need_blind_intl_since` | When need-blind admission for internationals started (group A only) |
| `on_lebeau_list` | `yes` / `no` |
| `lebeau_verdict` | `correct`, `incorrect`, `overstated`, `unclear`, `not_bachelors`, `missing`, `missing_adjacent`, `omitted_conditional`, `correctly_omitted` |
| `key_conditions` | The conditions that matter (loans, forms, round restrictions, transfers) |
| `official_source` | The school's own page used for the verdict |
| `confidence` | `High` = explicit official statement about international students; `Medium` = general statement, older page, or pages that disagree |
| `checked_on` | Date verified |
