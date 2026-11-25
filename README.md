# SelectYours

**Find a US college that will meet your full financial need as an international student.**

<!-- Live site: add the Vercel URL here once deployed -->
<!-- Screenshot: add an image here, e.g. ![SelectYours Explore page](docs/screenshot.png) -->

Most US colleges give international students little or no need-based aid. A small group promise to meet **100% of demonstrated need** for internationals. SelectYours covers those **62 colleges**. For each one it gathers aid policy, costs, admissions, academics, outcomes, student life, visas and work rules, climate, safety and health in one place. **Every number is sourced.**

## What's in it

- **Explore:** one table of all 62 schools with 57 filterable fields. It has range sliders with histograms, filter chips, presets, column views, side-by-side compare and CSV export. Each school opens a profile drawer with 13 sections.
- **Learn:** a guide for newcomers to US admissions and financial aid (need-blind vs need-aware, CSS Profile, Common Data Set and so on), plus the full ranking methodology.
- **Two original indexes:**
  - **Prestige Index:** 55% US standing (U.S. News 60 / Forbes 40), 30% global recognition (QS, THE, ARWU) and 15% endowment per student.
  - **Difficulty Index:** 60% admit rate, 20% SAT midpoint, 10% need policy and 10% aided international seats (CDS H6).
  - See [docs/methodology-prestige-difficulty.md](docs/methodology-prestige-difficulty.md).
- Fully responsive: phones get card layouts, an off-canvas filter panel and full-screen profiles.

## How it works

```
Official sources                 Research layer                  Build                 Website
────────────────                 ──────────────                  ─────                 ───────
University .edu pages  ──┐
Common Data Set PDFs   ──┼──▶  docs/universities/<slug>.md   ──┐
College Scorecard API  ──┤      (13 sections, footnoted)       │
NOAA climate normals   ──┤                                     ├──▶ tools/build-site.pl ──▶ site/
Published rankings     ──┘      docs/universities/_data/*.json ─┤      + site-src/            (static)
                                tools/compute-indexes.ps1  ─────┘
```

1. **Research:** each school has a markdown profile in [`docs/universities/`](docs/universities/README.md). Every fact is cited inline as `[n]`, with title, publisher, URL, data year and date checked.
2. **Data:** key metrics are stored per school in `docs/universities/_data/<slug>.json` as `{value, as_of, source, note}`. Shared data (rankings, endowments, the College Scorecard cache) lives in `_data/_*.json`.
3. **Indexes:** `tools/compute-indexes.ps1` computes both indexes and writes the ranking, the metrics CSV and the auto-generated blocks in each profile.
4. **Build:** `tools/build-site.pl` merges the profiles, JSON, CSVs and the hand-written source in `site-src/` into a static site in `site/`. Profiles are split into per-school files that load on demand.

### Data pipeline tools

| Script | Purpose |
| --- | --- |
| `new-school-json.ps1` | Builds a school's JSON from the College Scorecard baseline plus overrides |
| `noaa-nearest.ps1`, `climate-patches.ps1` | Finds the nearest NOAA 1991–2020 normals station to campus and writes climate lines |
| `add-majors.ps1` | Adds the most common fields of study (IPEDS via College Scorecard) |
| `i3.pl`, `i3b.pl`, `pdf-fields.pl` | Extract figures from Common Data Set PDFs, checking that table bands add up to their totals |
| `merge-profile-patch.ps1`, `apply-*.ps1` | Apply section patches and sourced findings to profiles |

## Tech

- Vanilla HTML, CSS and JavaScript: no framework, no bundler. It also runs straight from disk over `file://`.
- Perl for the site build and PDF extraction; PowerShell for data scripts.
- Public data APIs: U.S. Department of Education College Scorecard and NOAA NCEI.

## Run it locally

The built site is committed in `site/`, so you can just open `site/index.html` in a browser.

To rebuild after editing `docs/` or `site-src/` (needs Perl, for example from Git Bash):

```bash
perl tools/build-site.pl .
```

To recompute the indexes after changing anything in `docs/universities/_data/` (Windows PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\compute-indexes.ps1
```

To preview at http://localhost:8123/:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve-site.ps1
```

## Repository layout

| Path | Contents |
| --- | --- |
| `docs/` | Research: the full-need school list, methodology, ranking, CSVs and 62 school profiles |
| `site-src/` | Website source (edit these) |
| `site/` | Generated static site (don't hand-edit; rebuilt by `tools/build-site.pl`) |
| `tools/` | Data pipeline and build scripts |

## Data currency

The data covers the 2026–27 application cycle (Fall 2027 entry). Costs are 2026–27; admissions data are from CDS 2025–26 or the schools' Class of 2030 releases. Aid policies change every year, so always confirm on the school's official page before relying on a figure.

## Licence

Code is MIT-licensed. Research content and data are CC BY 4.0. Third-party data such as rankings and university figures remain under their owners' terms. See [LICENSE](LICENSE).

## Corrections

Found something wrong or out of date? Email shivamjoshi.bios@gmail.com with the school, the field and a source.
