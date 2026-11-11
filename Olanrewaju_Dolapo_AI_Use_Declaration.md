# Academic Integrity and AI-Use Declaration

**Student Name:** Olanrewaju Dolapo  
**Student ID:** 301911958  
**Programme:** Master of Science in Information Technology / Computing  
**Course Code:** MIT 8103 – Advanced Database Systems  
**Session:** 2026/2027 Academic Session (September Cohort)  
**Institution:** Miva Open University — School of Post Graduate Studies  
**Submission Title:** Individual Practical Database Portfolio (NairaPay Case Study)  

---

## 1. Scope of Artificial Intelligence Assistance

In accordance with Miva Open University's policy on academic integrity and the ethical use of artificial intelligence in postgraduate studies, this declaration transparently documents the extent, nature, and boundaries of AI assistance utilized during the completion of this portfolio assessment.

### AI Tools Utilized:
- **Anthropic Claude Code (Claude 3.7 Sonnet)**
- **Google Antigravity (Gemini 3.8 Flash / Pro)**

---

## 2. Specific Tasks Where AI Was Consulted

1. **Script Syntax Scaffolding & Boilerplate Generation:**
   - AI tools assisted in drafting initial templates for `pgbench` script syntax, Docker Compose service definitions, and PL/pgSQL variable declarations.
2. **Docker Orchestration & Entrypoint Debugging:**
   - Consulted AI for standard container entrypoint scripting (`gosu postgres`, waiting for healthcheck readiness via `until pg_isready`, and formatting `pg_basebackup` flags).
3. **Execution Plan Syntax Verification:**
   - Clarified PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` output terminology (e.g., Shared Hit vs. Read blocks, Parallel Append stages).
4. **Markdown Documentation & Report Formatting:**
   - Assisted in formatting markdown tables, aligning LaTeX equations, and structuring academic report layouts.

---

## 3. Student Ownership, Execution, and Empirical Verification

At no point was unverified AI-generated content submitted as empirical fact. All technical deliverables were subjected to rigorous independent execution and verification:

1. **Local and Cloud Execution:** Every SQL script, stored procedure, constraint test, Docker container, and MongoDB JavaScript query was manually deployed and executed on my local development workstation (macOS Apple Silicon) and live MongoDB Atlas cloud infrastructure.
2. **Empirical Telemetry Ownership:** Every execution metric reported across the five portfolio modules—including the **7,822.49 TPS** benchmark in Portfolio 3, the **412,058 row counts** in Portfolio 5, the **0.87 ms latency** in Portfolio 2, and the 11 terminal screenshots—was physically generated, captured, and validated on my live PostgreSQL 16 and MongoDB 7 instances.
3. **Intellectual Synthesis:** All architectural reasoning, design trade-off evaluations (e.g., synchronous vs. asynchronous replication, relational vs. document data placement, 2PC vs. Sagas), and technical reflections represent my own intellectual work and understanding of advanced database systems principles.

---

## 4. Formal Attestation

I hereby declare that:
1. This portfolio is my own original work, completed in fulfillment of the requirements for MIT 8103 at Miva Open University.
2. The AI tools referenced above were utilized strictly as developmental aids and pair-programming assistants, in full compliance with university guidelines.
3. I am prepared to explain, defend, and demonstrate any SQL query, stored procedure, MongoDB pipeline, execution plan, or architectural decision contained within this submission during any academic oral examination or assessment interview.

**Student Signature:** *Olanrewaju Dolapo*  
**Date:** November 11, 2026

