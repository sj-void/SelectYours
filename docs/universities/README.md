# University profiles: research guide

This folder holds one profile per school for the 62 schools that meet 100% of demonstrated need for international students ([../us-full-need-schools-international.md](../us-full-need-schools-international.md)). Each school has:

- `<slug>.md`: the full profile, written to [_TEMPLATE.md](_TEMPLATE.md).
- `_data/<slug>.json`: the key numbers in machine-readable form, for the website and the indexes.

Rankings and endowments are collected once for all schools, in `_data/_rankings.json` and `_data/_endowments.json`. The Prestige Index and the Difficulty Index are computed from these files using [../methodology-prestige-difficulty.md](../methodology-prestige-difficulty.md). The results go into [../prestige-and-difficulty-ranking.md](../prestige-and-difficulty-ranking.md) and into each profile's `AUTO` blocks.

## Coverage status (23 November 2026)

All 62 schools have a profile, a data file, and computed Prestige and Difficulty blocks. Depth varies:

- **All 13 template sections are filled in every profile.** No item says "Not researched" or "Not found" any more. Where a fact wasn't published, the profile says so and names the domain and date checked, for example "Not published on the pages checked (brandeis.edu, searched 2026-11-23)". After further passes on 23 Nov 2026, about 170 such statements remain across the 62 profiles (mostly notable alumni, class sizes, pre-health advising, aid-renewal rules and similar details that the schools don't publish).
- **Shared sources added 23 Nov 2026:**
  - Every profile has a climate line from NOAA 1991–2020 normals at the nearest station (found with the NCEI search service from College Scorecard coordinates).
  - Penn's and Rice's Box-hosted documents (the CDS and the Annual Security Report) were read in Box's online preview.
  - Security reports are linked for 34 more colleges. Every profile has a "most common fields" line (share of bachelor's degrees, IPEDS via College Scorecard). Counseling and disability services, break housing, nearest airport, insurance cost and waiver rules, testing and English-test policy, founding year and campus size, and notable alumni were filled for most schools from official pages.
- **Deep profiles (22):** Harvard, Yale, Princeton, MIT, Caltech, Stanford, Columbia, Barnard, Cornell, Penn, Brown, Dartmouth, Duke, Vanderbilt, Rice, Chicago, Northwestern, Notre Dame, Johns Hopkins, WashU, Rochester and Amherst. These have the most detail.
- **Core profiles (40):** the rest. Each has the key international facts (aid policy, forms, deadlines, aid numbers, cost, English tests and testing), federal admissions and outcome data, and short sections on academics, student life, campus, health and alumni.
- **Known data gaps:**
  - CDS H6 aid counts are missing for 16 schools (Colorado College's printed count conflicts with its total and average, so it isn't used); their Difficulty Index spreads that weight over the other components.
  - Brown publishes no CDS file. Notre Dame and Johns Hopkins block theirs (HTTP 403 or a bot-protection challenge, which we don't bypass). Their figures come from school releases and IPEDS via College Scorecard (cached in `_data/_scorecard.json`).
  - Some CDS PDFs (Caltech, Northwestern, Yale, Columbia, Cornell, Barnard) store the C7 grid in a form text extraction can't read, so C7 isn't reported for them.

## Rules (they apply to everyone who edits these files)

1. **Every fact has a source.** Put an inline `[n]` after the fact and list the source under "Sources" at the bottom. Give the title, the publisher, the full URL, the data year or edition, and the date checked. A fact you can't source stays out. Write "Not published (checked: <URL>)" instead.
2. **Never fill from memory or estimate.** Every number comes from a page or document that was actually read. If two official sources disagree, give both and say so.
3. **Source priority:**
   1. The school's own official site and documents (.edu pages, Common Data Set (CDS) PDF, financial-aid pages, the international student office, the catalog, the annual security report).
   2. US federal data: IPEDS / College Navigator (nces.ed.gov/collegenavigator), College Scorecard, the Campus Safety and Security data (ope.ed.gov/campussafety), NOAA climate normals.
   3. Official bodies: College Board, Common App, ETS, IELTS, Duolingo, QuestBridge, NSF.
   4. Reputable press, including student newspapers for admissions results. Label these as press.
   - **Never cited:** consultancy and admissions-coaching blogs (Crimson, CollegeVine, PrepScholar, Shemmassian, IvyWise, etc.), AI or SEO aggregator sites, forums (Reddit, College Confidential), or Wikipedia. They may be used only to find a lead, which must then be confirmed in a primary source.
4. **Use the newest data and label its year.**
   - Applicants are applying in the 2026–27 cycle for Fall 2027 entry. Today is late November 2026.
   - Costs: 2026–27. Deadlines and requirements: Fall 2027 entry.
   - Admissions statistics: CDS 2025–26 (Fall 2025 entrants), plus official Class of 2030 (Fall 2026) figures where the school has released them. If CDS 2025–26 isn't published, use 2024–25 and say so.
5. **Use the CDS item numbers** where relevant (C1, C7, C9, C21, C22, B1, B2, B22, H6, I2, I3, F1) so numbers can be re-checked.
6. **Don't copy long text.** Summarize essay prompts and policies in your own words. Quote at most one short phrase (under 15 words) where the exact wording matters, for example a full-need promise.
7. **Write for international students.** Note wherever a rule differs for internationals: aid forms, testing, English tests, deadlines, early-round limits, transfer aid, visas, jobs.
8. **Consistency with earlier research.** Our CSV already records each school's aid policy for internationals and the source for it. If you find something that contradicts it, report it. Don't silently change the verdict.

## Working efficiently (for research agents)

- **CDS PDFs:** when WebFetch saves a PDF locally, convert it with Bash (`pdftotext -layout "<file>.pdf" "<scratchpad>/<slug>-cds.txt"`). Then Grep the text for the item you need (e.g. `C1`, `H6`, `nonresident`, `SAT Evidence`). Read only the matching lines. Never read a whole PDF or text dump into context.
- **WebFetch:** give it a narrow question ("list the 2026-27 cost of attendance lines and amounts"), not "summarize the page". Don't fetch the same URL twice.
- **Write as you go:** save the profile after every two or three sections, so a limit or crash loses little.
- **Partial profiles:** if a profile already exists (it may be a draft with "Not yet researched" items), read it, keep what is sourced, fill the gaps, and remove the draft note when done.

## JSON format (`_data/<slug>.json`)

```json
{
  "school": "Official name",
  "slug": "file-slug",
  "checked_on": "2026-11-23",
  "metrics": {
    "applicants":        {"value": 0, "as_of": "Fall 2025 (CDS 2025-26 C1)", "source": "https://..."},
    "admits":            {"value": 0, "as_of": "...", "source": "..."},
    "enrolled_first_year": {"value": 0, "as_of": "...", "source": "..."},
    "admit_rate":        {"value": 0.0, "as_of": "...", "source": "...", "note": "percent, admits/applicants"},
    "admit_rate_class_of_2030": {"value": null, "as_of": "Fall 2026, school release", "source": null},
    "ed_applicants": {}, "ed_admits": {}, "ea_applicants": {}, "ea_admits": {},
    "sat_25": {}, "sat_75": {}, "act_25": {}, "act_75": {},
    "pct_submitting_sat": {}, "pct_submitting_act": {},
    "test_policy_fall_2027": {"value": "required | optional | blind | required for internationals only | other: ...", "source": "..."},
    "intl_applicants": {}, "intl_admits": {}, "intl_admit_rate": {},
    "intl_aided_count": {"value": 0, "as_of": "CDS 2025-26 H6", "source": "..."},
    "intl_avg_award": {}, "intl_total_aid": {},
    "intl_undergrad_count": {"value": 0, "as_of": "CDS 2025-26 B2 (nonresidents)", "source": "..."},
    "total_undergrad": {}, "total_enrollment": {"value": 0, "as_of": "CDS 2025-26 B1 (all students incl. graduate)", "source": "..."},
    "coa_total_2026_27": {}, "tuition_2026_27": {},
    "grad_rate_4yr": {}, "grad_rate_6yr": {}, "retention_rate": {},
    "student_faculty_ratio": {}
  },
  "notes": ["Anything a reader of the numbers must know"]
}
```

For anything not found, use `{"value": null, "note": "Not published (checked: URL)"}`. Percentages are numbers out of 100 (4.6 means 4.6%).

## Slugs

harvard-university, yale-university, princeton-university, massachusetts-institute-of-technology, california-institute-of-technology, stanford-university, columbia-university, barnard-college, cornell-university, university-of-pennsylvania, brown-university, dartmouth-college, duke-university, vanderbilt-university, rice-university, university-of-chicago, northwestern-university, university-of-notre-dame, johns-hopkins-university, washington-university-in-st-louis, university-of-rochester, new-york-university, tufts-university, brandeis-university, amherst-college, williams-college, bowdoin-college, swarthmore-college, haverford-college, bryn-mawr-college, pomona-college, claremont-mckenna-college, pitzer-college, wellesley-college, smith-college, mount-holyoke-college, middlebury-college, colby-college, bates-college, hamilton-college, colgate-university, vassar-college, wesleyan-university, trinity-college, connecticut-college, davidson-college, washington-and-lee-university, university-of-richmond, grinnell-college, carleton-college, macalester-college, colorado-college, reed-college, whitman-college, lafayette-college, franklin-and-marshall-college, skidmore-college, college-of-the-holy-cross, denison-university, oberlin-college, rhodes-college, berea-college
