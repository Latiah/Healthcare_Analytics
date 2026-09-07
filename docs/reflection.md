# Reflection

## Why Is the Star Schema Faster?

The normalized OLTP database is designed for storing transactional data efficiently. However, answering analytical questions requires joining several related tables. As the number of records increases, these joins become more expensive and slow down query execution.

The star schema improves performance by placing the fact table at the center and connecting it directly to dimension tables, and by storing commonly used measures — total claim amount, total allowed amount, diagnosis count, procedure count, length of stay, and the 30-day readmission flag — directly on the fact row so they are not recalculated on every report run.

The measured results in this project qualify that textbook explanation in one important way. Shortening the join chain turned out to matter least: Q1 actually joins *more* tables in the star schema (2 joins to 3) and was still marginally faster, and Q2's join count did not change at all. What mattered was moving work out of query time and into ETL time — storing `year` and `month` as real columns instead of deriving them per row with `DATE_FORMAT()`, and precomputing `readmission_flag` instead of recomputing a self-join on every run. The star schema is faster here mainly because it does work once at load time rather than repeatedly at query time, not because it removes joins.

---

## Trade-offs: What Did You Gain? What Did You Lose?

### Gains

- Simpler SQL queries — the clearest gain, and the only one that does
  not depend on dataset size. Q3 drops from a self-join guarded by
  `COUNT(DISTINCT CASE ...)` to a plain `AVG(readmission_flag)`.
- Faster analytical queries, measured at ~1.09x to ~4.11x here. Modest,
  for the reasons set out under Performance Comparison below.
- Harder to get wrong. The OLTP readmission query needed
  `COUNT(DISTINCT ...)` on both sides of the ratio to avoid
  double-counting rows the self-join duplicated — a trap this project
  originally fell into. The star schema version cannot make that
  mistake, because the flag is already one value per encounter. For a
  figure that feeds CMS reporting, that matters more than the speed.
- Easier business intelligence and dashboard development.

### Losses

- Some data is duplicated in dimension tables.
- The ETL process becomes more complex.
- More storage space is required.

Overall, the advantages outweigh the disadvantages because analytical databases are optimized for reading large amounts of data rather than processing transactions.

---

## Bridge Tables: Were They Worth It?

Yes.

An encounter can contain multiple diagnoses and multiple procedures. Keeping these relationships in bridge tables preserves the original business relationships without duplicating rows in the fact table.

If diagnoses and procedures were stored directly in the fact table, encounter records would have to be duplicated whenever multiple diagnoses or procedures exist. Bridge tables avoid this problem while keeping the star schema flexible.

The honest qualification is that they were worth it for **grain integrity, not for speed**. Keeping the fact table at one row per encounter is what lets every other measure on it — revenue, length of stay, readmission flag — be summed without double counting. That is the real payoff, and for a hospital it is the difference between a revenue figure a finance team can trust and one inflated by however many diagnoses each encounter happened to carry. Q2, the only query that actually reads the bridges, is also the query where the star schema helps least: the join count is unchanged and the diagnosis-procedure row explosion remains, because that pairing is what the question asks for. Bridge tables protected the model; they did not accelerate it.

---

## Performance Comparison

All figures below are the measured timings recorded in
`star_schema_queries.txt`, on the sample dataset of ~315 encounters.

| Query | OLTP | Star schema | Improvement | Joins (OLTP → star) |
|---|---|---|---|---|
| Q1 Monthly encounters by specialty | 5.19 ms | 4.75 ms | ~1.09x | 2 → 3 |
| Q2 Top diagnosis-procedure pairs | 6.6 ms | 0.0499 ms | ~132x (unreliable) | 3 → 3 |
| Q3 30-day readmission rate | 6.7 ms | 1.63 ms | ~4.11x | 3 → 2 |
| Q4 Revenue by specialty & month | 4.27 ms | 2.72 ms | ~1.57x | 3 → 2 |

### Reading these numbers honestly

The gains are smaller than the theory would suggest, and the reason is
the dataset. At ~315 encounters the whole database fits in memory and
every join runs against an indexed primary key, so a join costs almost
nothing. The star schema does less work per row, but with only 315 rows
"less work" saves very little absolute time.

The pattern worth noticing is that **improvement tracks whether work was
eliminated or merely reduced**, not how many joins were removed:

- Q1 and Q4 only *reduced* work. Q1 actually went from 2 joins to 3 —
  the star schema version joins more tables and was still slightly
  faster, because `year` and `month` are stored columns in `dim_date`
  rather than being derived per row with `DATE_FORMAT()`.
- Q3 *eliminated* work. The self-join is gone entirely, precomputed
  once in ETL as `readmission_flag`. This is the most trustworthy
  result of the four, and the only one that would grow with data
  volume.
- **Q2's ~132x does not hold up.** The join count is unchanged (3 → 3)
  and the query still pairs every diagnosis with every procedure on an
  encounter, so the star schema removes no structural work here. Any
  genuine gain comes only from the bridge tables being narrower and
  keyed directly on the join column. On top of that, 0.0499 ms is below
  the reliable measurement floor for this setup, so the magnitude is a
  timer artifact rather than a real 132-fold speedup. This is the
  weakest of the four claims and should not be quoted as a headline
  result.

---

## Why This Matters to a Hospital

Query performance is the means, not the end. Each of these four
questions maps to a decision someone in the organisation has to make.

**Readmission rate (Q3) is the one with money attached.** Under the CMS
Hospital Readmissions Reduction Program, hospitals with higher-than-
expected 30-day readmission rates face reduced Medicare reimbursement
across *all* their admissions, not just the readmitted ones. A
specialty-level readmission rate is therefore a financial exposure
report as much as a clinical one: it shows which service lines are
driving a penalty and where a discharge-planning or follow-up
intervention would pay for itself. Storing `readmission_flag` on the
fact table matters because this figure gets pulled repeatedly — for
monthly quality review, for board reporting, and for tracking whether
an intervention actually moved the number.

**Revenue by specialty and month (Q4) drives staffing and capacity.**
Knowing that Cardiology bills heavily in Q1 but drops in Q3 is what
justifies moving staff, theatre time, or clinic slots between service
lines. Because it uses `allowed_amount` rather than `claim_amount`, it
reflects what payers actually reimburse rather than what was billed —
the difference between the two is exactly what a revenue-cycle team
investigates.

**Diagnosis-procedure pairs (Q2) are a care-pattern and coding-audit
tool.** Knowing which procedures habitually accompany a diagnosis
supports two concrete uses: building care pathways and order sets for
common presentations, and flagging pairings that look clinically
unusual, which is how both coding errors and outlier practice get
found. It also feeds cost-per-episode estimates, since a diagnosis's
real cost is the cost of the procedures that follow it. This is why the
pairing is worth computing even though it is the query the star schema
helps least.

**Monthly encounter volume by specialty (Q1)** is the baseline capacity
and demand-planning report — clinic templates, rota sizing, and
detecting seasonal load such as winter respiratory presentations.

---

## Conclusion

This project demonstrates why dimensional modeling is widely used in data warehouses. Designing and maintaining a star schema requires additional ETL work and introduces some data duplication, and in exchange the analytical queries become considerably simpler to write and read — a benefit that is immediate and independent of dataset size.

The performance benefit is more conditional. On this dataset the measured gains ran from ~1.09x to ~4.11x, with the largest trustworthy gain coming from the one query where ETL precomputation removed an expensive operation outright rather than just shortening a join chain. At small scale a star schema mostly buys clarity; the performance case rests on eliminating repeated work, and on datasets large enough for join and row-explosion costs to actually register.

For a hospital the practical value is that these four reports become cheap enough to run routinely rather than as one-off extracts — which is what turns a readmission rate from an annual audit figure into something a service line can actually manage against.