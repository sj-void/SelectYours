# How we measure prestige and admission difficulty

**Status:** final, version 1.1 (23 November 2026). Changes from the first draft and the reasons are in section 5.

> **Version 1.1 change:** WSJ/College Pulse 2026 is no longer scored. Only its top 100 is public (the full list is paywalled), so 33 of our 62 schools have no WSJ rank, and the WSJ partnership has ended, so no 2027 edition is coming. Pillar A is now **60% U.S. News 2027 + 40% Forbes 2027**. The WSJ rank is still shown for schools in its top 100. The tables below describe version 1; read the WSJ weight as moved to these two.
>
> **Data note (v1.1):**
> - The admit rate, SAT and enrollment come from each school's CDS 2025–26 (Fall 2025), or its official Class of 2030 release, where these could be read.
> - Where a CDS was blocked, unpublished, or only an interactive dashboard, the same figures come from federal IPEDS data for Fall 2024, via the College Scorecard API. For those schools the SAT midpoint is the sum of the section midpoints. This applied to about half the list, and each profile labels its year and source.
> - Where only ACT ranges exist, the SAT midpoint is converted with the official 2018 ACT/SAT concordance (act.org).
> - Six endowments (Wellesley, Mount Holyoke, Berea, Pitzer, Franklin & Marshall, Denison) use the latest published value, June 2024 or approximate, because FY2025 figures were not found. Each is labelled in `universities/_data/_endowments.json`.
**Applies to:** the 62 schools in [us-full-need-schools-international.md](us-full-need-schools-international.md).
**Audience:** international students who need full financial aid.

Every source is listed at the bottom, numbered `[n]`.

---

## 1. Principles

- **No single ranking covers all 62 schools fairly.**
  - 24 of the 62 are universities and 38 are liberal arts colleges (LACs), using the classification in our CSV.
  - U.S. News ranks those two groups on separate lists [1].
  - QS only ranks institutions that offer both undergraduate and postgraduate degrees [2].
  - THE excludes institutions with fewer than 1,000 publications over five years [3].
  - Only 17 of the 62 are on the UK's list of globally top-ranked universities [13].
- **Rankings feed on themselves and depend on self-reported data.** Published ranks shape later reputation scores [10], and Columbia's misreported data got it removed from the 2023 U.S. News edition [11]. So every component is shown, never just a final number.
- **Prestige and difficulty are kept separate.** A school can be prestigious but easier to get into, and students should be able to see that.
- **Fixed formulas and tier cut-offs were set before any school was scored**, so no result could be tuned after the fact.
- **Missing data:** if a school has no value for a component, that component's weight is spread proportionally over the school's other components, and the school is flagged "partial data".

---

## 2. Prestige Index (0–100)

"Prestige" here means how highly the degree is regarded by employers and graduate schools in the US, by employers and governments abroad, and by the academic world.

| Pillar | Weight | Measure | Source and edition |
| --- | --- | --- | --- |
| **A. US standing** | **55%** | Weighted average of three national ranks:<br>• U.S. News 2027 rank within its own category, 50%<br>• Forbes 2027, 30%<br>• WSJ/College Pulse 2026, 20% | • U.S. News Best Colleges 2027, published 21 Sept 2026 [1]<br>• Forbes America's Top Colleges 2027, published 10 Sept 2026 [4]<br>• WSJ/College Pulse 2026, the latest edition; no 2027 edition found as of 23 Nov 2026 [5] |
| **B. Global recognition** | **30%** | Average of three global ranks; a school not on a list scores 0 for that list | • QS World University Rankings 2027, June 2026 [2][6]<br>• THE World University Rankings 2027, 30 Sept 2026 [3][7]<br>• ARWU 2026, 15 Aug 2026 [8] |
| **C. Wealth per student** | **15%** | Endowment ÷ total enrolled students (headcount) | • NACUBO-Commonfund Study of Endowments FY2025, Feb 2026, or the school's FY2025 financial report [17]<br>• Enrollment from Common Data Set (CDS) item B1 [21] |

**Why these sources:**
- **U.S. News** is the only US ranking with a direct reputation survey: 20% of its score comes from ratings by presidents, provosts and deans [1].
- **Forbes** puts universities and LACs on a single list and rewards alumni leadership (15%) and fellowships and PhDs (10%) [4].
- **WSJ** is mostly about value added, with 70% of its score from outcomes, so it gets the smallest share of pillar A [5].
- **QS, THE and ARWU** measure how the name is known worldwide:
  - QS surveys 151,000 academics and 100,000 employers [2].
  - THE's reputation measures (33%) come from 69,000+ responses [3].
  - ARWU counts Nobel and Fields winners, highly cited researchers and Nature/Science papers [8].
  - Governments use these rankings: the UK's High Potential Individual visa accepts only graduates of universities in the top 100 of at least two of the three [13][14].
- **Endowment per student** measures real resources, and also signals whether a school can keep funding international aid.

**Turning ranks into points:**
- National ranks: `100 × (1 − √((rank − 1) / 249))`, with a minimum of 0. Roughly: #1 = 100, #10 = 81, #50 = 56, #100 = 23, #250 and below = 0.
- Global ranks: `100 × (1 − √((rank − 1) / 399))`. Roughly: #1 = 100, #50 = 65, #150 = 39, #400 and below = 0.
- For a range such as "201–250", the midpoint is used.
- Wealth uses a log scale with fixed ends: `100 × ln(per-student endowment / $100,000) / ln(30)`, limited to 0–100. So $100k = 0 and $3M = 100.

**Prestige tiers:**

| Tier | Score |
| --- | --- |
| Tier 1, world-renowned | 70 or more |
| Tier 2, elite | 55–69.9 |
| Tier 3, highly regarded | 40–54.9 |
| Tier 4, respected | below 40 |

**Also shown, but not scored:**
- The **US standing** and **global recognition** sub-scores on their own. Students who care about one side can read it directly.
- Ivy League; Ivy-Plus (the 8 Ivies plus Chicago, Duke, MIT and Stanford) [19].
- 2025 Carnegie R1 research status [20]; AAU membership.
- UK HPI 2026 list membership [13].
- "Top-25 producer of PhDs per graduate," from NSF data compiled by Swarthmore [28].

---

## 3. Difficulty Index (0–100)

"Difficulty" here means how hard it is for an international student who needs full aid to get in.

| Component | Weight | Measure | Source |
| --- | --- | --- | --- |
| **1. Overall admit rate** | **60%** | First-year admits ÷ applicants, latest official cycle | CDS 2025–26 item C1, or the school's official Class of 2030 figures if newer [21][22]. CDS 2024–25 if 2025–26 isn't out (labelled). |
| **2. Academic bar** | **20%** | Midpoint of the SAT 25th–75th percentiles, with ACT converted using the official concordance | CDS items C8–C9 [21] |
| **3. Need policy** | **10%** | Need-blind for internationals = 0; need-aware or need-sensitive = 100 | Our verified list [24] |
| **4. Aid seats** | **10%** | International undergraduates receiving institutional aid ÷ 4, which gives roughly the aided seats per class | CDS item H6 [23] |

**Turning data into points:**
- Admit rate, log scale: `100 × ln(60% / rate) / ln(20)`. So 3% = 100 and 60% = 0.
- SAT midpoint, linear: 1300 = 0, 1560 = 100.
- Aid seats, log scale: `100 × ln(150 / seats) / ln(30)`. So 5 or fewer seats = 100 and 150 or more = 0.

**Difficulty tiers:**

| Tier | Score |
| --- | --- |
| Extreme | 70 or more |
| Very high | 55–69.9 |
| High | 40–54.9 |
| Competitive | below 40 |

No school on this list is easy.

**Also shown, but not scored:**
- The international-only admit rate, where the school publishes it officially. It isn't scored because most schools don't publish it, and scoring it would make the ones that do look harder.
- Early Decision and Early Action admit rates (CDS C21–C22), and whether internationals can apply early and still get aid.
- Yield: the share of admitted students who enroll.
- International share of students.
- Test policy for Fall 2027 [25].

---

## 4. Left out on purpose

| Source | Why not |
| --- | --- |
| PhDs per graduate (NSF) as a scored pillar | Data is published only for the top 25 to 50 schools [15][28], which is just 21 of our 62. It's shown as a marker instead. Forbes already counts PhDs and fellowships [4]. |
| Niche 2027 [26] | Driven by student reviews. It's used, labelled as reviews, in the campus-life section. |
| Admit rate in prestige | Would count twice. |
| College Scorecard earnings, for ranking | Covers students on US federal aid only, which excludes internationals [12]. Shown as context with that caveat. |
| Revealed-preference ranking [9] | The strongest method in principle, but its data is from around 2000 and was never updated. |
| THE World Reputation Rankings [27] | The latest edition found is 2025, and reputation already counts through QS and THE 2027. |
| Consultancy blogs | Not primary sources. Used only to find leads, never cited. |

---

## 5. Changes from the first draft, and why

1. **Dropped the scholarly-pipeline pillar from the score.** Institution-level NSF figures only exist for the top 25 to 50 schools, so two-thirds of the list would have been scored on missing data.
2. **Pillar A weights: U.S. News 50, Forbes 30, WSJ 20.** Only U.S. News has a reputation survey. WSJ measures value added rather than prestige, and its latest edition is a year older.
3. **Wider rank curves** (national to #250, global to #400). The draft's #150 cut-off pushed schools ranked around #40–#80, still in the top 10–20% nationally, too low.
4. **Wealth on a fixed log scale** instead of a percentile, so scores don't change when schools are added or removed.
5. **Difficulty reweighted (admit rate 60, tests 20, need policy 10, aid seats 10).** The draft made generous need-blind schools such as Harvard look easier than they are. The admit rate is both the most reliable number and the main driver of difficulty.
6. **Tier cut-offs fixed before scoring.**

---

## Sources

1. U.S. News, "How U.S. News Calculated the 2027 Best Colleges Rankings," 21 Sept 2026: https://www.usnews.com/education/best-colleges/articles/how-us-news-calculated-the-rankings
2. QS, "QS World University Rankings" methodology and eligibility: https://support.qs.com/hc/en-gb/articles/4405955370898-QS-World-University-Rankings
3. THE, "World University Rankings 2027: methodology," 15 Sept 2026: https://www.timeshighereducation.com/world-university-rankings/methodology
4. Forbes, "How Forbes Ranked America's Top 500 Colleges for 2027," 10 Sept 2026: https://www.forbes.com/sites/lisachambers/2026/09/10/how-we-rank-americas-best--colleges/
5. WSJ/College Pulse 2026 coverage: https://poetsandquantsforundergrads.com/news/ranking-stanford-tops-wall-street-journals-2025-best-colleges-in-america/ ; partnership status: https://statista.com/page/us-college-rankings
6. QS World University Rankings 2027 results: https://www.qs.com/en-us/insights%2Fqs-world-university-rankings ; coverage: https://poetsandquants.com/2026/06/23/how-mit-again-topped-the-qs-world-university-rankings/
7. THE World University Rankings 2027 launch: https://www.timeshighereducation.com/world-university-rankings-2027-launch
8. ShanghaiRanking, "ARWU Methodology 2026": https://www.shanghairanking.com/methodology/arwu/2026
9. Avery, Glickman, Hoxby and Metrick, "A Revealed Preference Ranking of U.S. Colleges and Universities," *QJE* 2013: https://www.nber.org/papers/w10803
10. Bastedo and Bowman, *American Journal of Education*, 2010: https://public.websites.umich.edu/~bastedo/papers/BastedoBowman.AJE2009.pdf
11. M. Thaddeus, Columbia ranking investigation, 2022: https://www.math.columbia.edu/~thaddeus/ranking/investigation.html ; https://www.highereddive.com/news/us-news-removes-columbia-u-from-this-years-rankings-amid-investigation/626861/
12. College Scorecard Institution-Level Data Documentation: https://collegescorecard.ed.gov/assets/InstitutionDataDocumentation.pdf
13. UK Home Office, HPI global universities list 2026, updated 4 Nov 2026: https://www.gov.uk/government/publications/high-potential-individual-visa-global-universities-list/high-potential-individual-visa-global-universities-list-2026
14. UK Immigration Rules HC 1333, 14 Oct 2025 (Global Universities List definition): https://www.gov.uk/government/publications/statement-of-changes-to-the-immigration-rules-hc-1333-14-october-2025/statement-of-changes-to-the-immigration-rules-hc-1333-14-october-2025-accessible-version
15. NSF NCSES, "Baccalaureate Origins of U.S. Research Doctorate Recipients" (NSF 22-321): https://ncses.nsf.gov/pubs/nsf22321
16. NSF NCSES, NSF 25-349 Table 7-9: https://ncses.nsf.gov/pubs/nsf25349/assets/data-tables/tables/nsf25349-tab007-009.pdf
17. NACUBO-Commonfund Study of Endowments FY2025: https://edge.sitecorecloud.io/nacubo1-nacubo-prd-dc8b/media/Nacubo/Documents/EndowmentFiles/2025-NCSE---Summary-and-Key-Insights-from-the-2025-NCSE-FINAL.pdf
18. NCES IPEDS: https://nces.ed.gov/ipeds/
19. Chetty, Deming and Friedman, NBER w31492, 2023: https://www.nber.org/papers/w31492
20. ACE/Carnegie 2025 Research Activity Designations: https://carnegieclassifications.acenet.edu/news/carnegie-classifications-release-2025-research-activity-designations-debut-updated-methodology/
21. Common Data Set 2025–2026 templates: https://groups.google.com/a/collegeboard.org/g/commondataset/c/7leHvGPAYuY
22. The Tech (MIT), Class of 2030, 19 Mar 2026: https://www.thetech.com/2026/03/19/class-of-2030-rd
23. CDS 2025–26 item H6, example (University of Nebraska–Lincoln): https://iea.unl.edu/common-data-set-2025-2026/h-financial-aid/aid-undergraduate-degree-seeking-nonresidents
24. [us-full-need-schools-international.csv](us-full-need-schools-international.csv), verified 22 Nov 2026
25. Columbia testing policy: https://communications.news.columbia.edu/news/update-columbia-college-and-columbia-engineering-testing-policy ; Fall 2027 list: https://thecollegeinvestor.com/77443/colleges-are-requiring-sat-and-act-scores-again-heres-the-full-list-for-2027/
26. Niche 2027 Best Colleges, 31 Aug 2026: https://www.niche.com/about/2027-best-colleges-rankings/
27. THE World Reputation Rankings 2025: https://www.timeshighereducation.com/world-reputation-rankings
28. Swarthmore College Institutional Research, "Doctorates Awarded" (NSF Survey of Earned Doctorates 2015–2024 ÷ IPEDS bachelor's 2006–2015; top-25 table): https://www.swarthmore.edu/institutional-research/doctorates-awarded
