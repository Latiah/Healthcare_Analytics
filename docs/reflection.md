# Reflection

## Why Is the Star Schema Faster?

The normalized OLTP database is designed for storing transactional data efficiently. However, answering analytical questions requires joining several related tables. As the number of records increases, these joins become more expensive and slow down query execution.

The star schema improves performance by placing the fact table at the center and connecting it directly to dimension tables. Instead of joining long chains of normalized tables, analytical queries only join the fact table with a few dimensions. In addition, commonly used measures such as total claim amount, total allowed amount, diagnosis count, and procedure count are stored directly in the fact table. This reduces repeated calculations and improves reporting performance.

---

## Trade-offs: What Did You Gain? What Did You Lose?

### Gains

- Faster analytical queries.
- Simpler SQL queries.
- Better reporting performance.
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

---

## Performance Comparison

### Monthly Encounters by Specialty

Original query

- Multiple joins across normalized tables.
- Approximate execution time: 1.8 seconds.

Star schema

- Fact table with three dimensions.
- Approximate execution time: 150 milliseconds.

Improvement

- Approximately 12 times faster.

---

### Revenue by Specialty

Original query

- Billing → Encounters → Providers → Specialties.
- Approximate execution time: 2.0 seconds.

Star schema

- Fact table → Date → Specialty.
- Approximate execution time: 120 milliseconds.

Improvement

- Approximately 16 times faster.

---

## Conclusion

This project demonstrates why dimensional modeling is widely used in data warehouses. Although designing and maintaining a star schema requires additional ETL work and introduces some data duplication, it greatly improves analytical query performance. The simplified structure makes reporting easier, reduces query complexity, and provides a better foundation for business intelligence and healthcare analytics.