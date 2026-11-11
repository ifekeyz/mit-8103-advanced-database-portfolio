#!/usr/bin/env bash
# ==============================================================================
# MIVA OPEN UNIVERSITY — SCHOOL OF POST GRADUATE STUDIES
# MIT 8103: Advanced Database Systems
# Automated Submission Packaging Script
# Student: Olanrewaju Dolapo (Student ID: 301911958)
# ==============================================================================
set -euo pipefail

SURNAME="Olanrewaju"
FIRSTNAME="Dolapo"
STUDENT_ID="301911958"
PREFIX="${SURNAME}_${FIRSTNAME}"
TARGET_DIR="${PREFIX}_${STUDENT_ID}"
ZIP_NAME="${TARGET_DIR}.zip"

echo "================================================================================"
echo " Packaging Miva MIT 8103 Submission for ${FIRSTNAME} ${SURNAME} (${STUDENT_ID})"
echo "================================================================================"

# 1. Clean previous build
rm -rf "${TARGET_DIR}" "${ZIP_NAME}"
mkdir -p "${TARGET_DIR}"

SRC="MIT8103"

echo "[1/6] Copying and standardizing Final Synthesis Documentation..."
cp Olanrewaju_Dolapo_Final_Report.md "${TARGET_DIR}/${PREFIX}_Final_Report.md"
cp Olanrewaju_Dolapo_README.txt "${TARGET_DIR}/${PREFIX}_README.txt"
cp Olanrewaju_Dolapo_AI_Use_Declaration.md "${TARGET_DIR}/${PREFIX}_AI_Use_Declaration.md"
cp Olanrewaju_Dolapo_References.md "${TARGET_DIR}/${PREFIX}_References.md"

echo "[2/6] Packaging Portfolio 1: Database Design & Modelling..."
cp "${SRC}/portfolio-1-database-design/case-study.md" "${TARGET_DIR}/${PREFIX}_P1_CaseStudy.md"
cp "${SRC}/portfolio-1-database-design/README.md" "${TARGET_DIR}/${PREFIX}_P1_RelationalSchema.md"
cp "${SRC}/portfolio-1-database-design/normalisation.md" "${TARGET_DIR}/${PREFIX}_P1_Normalisation.md"
cp "${SRC}/portfolio-1-database-design/00_create_database.sql" "${TARGET_DIR}/${PREFIX}_P1_CreateDatabase.sql"
cp "${SRC}/portfolio-1-database-design/02_create_tables.sql" "${TARGET_DIR}/${PREFIX}_P1_CreateSchema.sql"
cp "${SRC}/portfolio-1-database-design/03_constraint_tests.sql" "${TARGET_DIR}/${PREFIX}_P1_ConstraintTests.sql"
cp "${SRC}/portfolio-1-database-design/04_seed_data.sql" "${TARGET_DIR}/${PREFIX}_P1_SeedData.sql"
cp "${SRC}/portfolio-1-database-design/05_verify_seed.sql" "${TARGET_DIR}/${PREFIX}_P1_VerifySeed.sql"
cp "${SRC}/portfolio-1-database-design/nairapay.dbml" "${TARGET_DIR}/${PREFIX}_ERD.dbml"
cp "${SRC}/portfolio-1-database-design/screenshots/er-diagram.png" "${TARGET_DIR}/${PREFIX}_ERD.png"
cp "${SRC}/portfolio-1-database-design/screenshots/01-setup.png" "${TARGET_DIR}/${PREFIX}_P1_Screen_Setup.png"
cp "${SRC}/portfolio-1-database-design/screenshots/02-tables-created.png" "${TARGET_DIR}/${PREFIX}_P1_Screen_Tables.png"
cp "${SRC}/portfolio-1-database-design/screenshots/03-constraint-tests.png" "${TARGET_DIR}/${PREFIX}_P1_Screen_Constraints.png"

echo "[3/6] Packaging Portfolio 2: Query Optimisation & Performance Tuning..."
cp "${SRC}/portfolio-2-query-optimisation/README.md" "${TARGET_DIR}/${PREFIX}_P2_README.md"
cp "${SRC}/portfolio-2-query-optimisation/performance-analysis.md" "${TARGET_DIR}/${PREFIX}_P2_PerformanceResults.md"
cp "${SRC}/portfolio-2-query-optimisation/sql/01_capture_plans.sql" "${TARGET_DIR}/${PREFIX}_P2_CapturePlans.sql"
cp "${SRC}/portfolio-2-query-optimisation/sql/02_query_results.sql" "${TARGET_DIR}/${PREFIX}_P2_Queries.sql"
cp "${SRC}/portfolio-2-query-optimisation/sql/03_create_indexes.sql" "${TARGET_DIR}/${PREFIX}_P2_CreateIndexes.sql"
cp "${SRC}/portfolio-2-query-optimisation/sql/04_drop_indexes.sql" "${TARGET_DIR}/${PREFIX}_P2_DropIndexes.sql"
cp "${SRC}/portfolio-2-query-optimisation/sql/05_planner_experiments.sql" "${TARGET_DIR}/${PREFIX}_P2_PlannerExperiments.sql"
cp "${SRC}/portfolio-2-query-optimisation/sql/06_write_cost.sql" "${TARGET_DIR}/${PREFIX}_P2_WriteCost.sql"
cp "${SRC}/portfolio-2-query-optimisation/plans/before.txt" "${TARGET_DIR}/${PREFIX}_P2_Out_Before.txt"
cp "${SRC}/portfolio-2-query-optimisation/plans/after.txt" "${TARGET_DIR}/${PREFIX}_P2_Out_After.txt"
cp "${SRC}/portfolio-2-query-optimisation/plans/planner.txt" "${TARGET_DIR}/${PREFIX}_P2_Out_Planner.txt"
cp "${SRC}/portfolio-2-query-optimisation/plans/results.txt" "${TARGET_DIR}/${PREFIX}_P2_Out_Results.txt"

echo "[4/6] Packaging Portfolio 3: Transactions & Concurrency Control..."
cp "${SRC}/portfolio-3-transactions-concurrency/README.md" "${TARGET_DIR}/${PREFIX}_P3_README.md"
cp "${SRC}/portfolio-3-transactions-concurrency/analysis.md" "${TARGET_DIR}/${PREFIX}_P3_ConcurrencyAnalysis.md"
cp "${SRC}/portfolio-3-transactions-concurrency/04_concurrency_runbook.md" "${TARGET_DIR}/${PREFIX}_P3_Runbook.md"
cp "${SRC}/portfolio-3-transactions-concurrency/01_transfer_function.sql" "${TARGET_DIR}/${PREFIX}_P3_TransactionScripts.sql"
cp "${SRC}/portfolio-3-transactions-concurrency/02_demo_setup.sql" "${TARGET_DIR}/${PREFIX}_P3_DemoSetup.sql"
cp "${SRC}/portfolio-3-transactions-concurrency/03_commit_rollback_demo.sql" "${TARGET_DIR}/${PREFIX}_P3_CommitRollbackDemo.sql"
cp "${SRC}/portfolio-3-transactions-concurrency/07_integrity_check.sql" "${TARGET_DIR}/${PREFIX}_P3_IntegrityCheck.sql"
cp "${SRC}/portfolio-3-transactions-concurrency/05_stress_ordered.pgbench" "${TARGET_DIR}/${PREFIX}_P3_StressOrdered.pgbench"
cp "${SRC}/portfolio-3-transactions-concurrency/06_stress_unordered.pgbench" "${TARGET_DIR}/${PREFIX}_P3_StressUnordered.pgbench"
cp "${SRC}/portfolio-3-transactions-concurrency/output/03_commit_rollback_output.txt" "${TARGET_DIR}/${PREFIX}_P3_Out_CommitRollback.txt"
cp "${SRC}/portfolio-3-transactions-concurrency/output/stress_ordered.txt" "${TARGET_DIR}/${PREFIX}_P3_Out_StressOrdered.txt"
cp "${SRC}/portfolio-3-transactions-concurrency/output/stress_unordered.txt" "${TARGET_DIR}/${PREFIX}_P3_Out_StressUnordered.txt"
cp "${SRC}/portfolio-3-transactions-concurrency/output/integrity_before.txt" "${TARGET_DIR}/${PREFIX}_P3_Out_IntegrityBefore.txt"
cp "${SRC}/portfolio-3-transactions-concurrency/output/integrity_after_ordered.txt" "${TARGET_DIR}/${PREFIX}_P3_Out_IntegrityAfterOrdered.txt"
cp "${SRC}/portfolio-3-transactions-concurrency/output/integrity_after_unordered.txt" "${TARGET_DIR}/${PREFIX}_P3_Out_IntegrityAfterUnordered.txt"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/01_function_test.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_FunctionTest.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/02_commit_rollback_output.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_CommitRollback.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/03_exp1_lost_update.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_Exp1LostUpdate.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/04_exp2_lock_released.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_Exp2LockReleased.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/05_exp2_lock_waiting.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_Exp2LockWaiting.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/06_exp3a_read_committed.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_Exp3aReadCommitted.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/07_exp3b_repeatable_read.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_Exp3bRepeatableRead.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/08_exp4_deadlock.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_Exp4Deadlock.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/09_stress_results.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_StressResults.png"
cp "${SRC}/portfolio-3-transactions-concurrency/screenshots/10_integrity.png" "${TARGET_DIR}/${PREFIX}_P3_Screen_IntegrityAudit.png"

echo "[5/6] Packaging Portfolio 4: NoSQL & Advanced Data Models (MongoDB)..."
cp "${SRC}/portfolio-4-nosql/README.md" "${TARGET_DIR}/${PREFIX}_P4_README.md"
cp "${SRC}/portfolio-4-nosql/analysis.md" "${TARGET_DIR}/${PREFIX}_P4_NoSQLAnalysis.md"
cp "${SRC}/portfolio-4-nosql/00_docker_setup.md" "${TARGET_DIR}/${PREFIX}_P4_DockerSetup.md"
cp "${SRC}/portfolio-4-nosql/docker-compose.yml" "${TARGET_DIR}/${PREFIX}_P4_DockerCompose.yml"
cp "${SRC}/portfolio-4-nosql/01_schema_validation.js" "${TARGET_DIR}/${PREFIX}_P4_SchemaValidation.js"
cp "${SRC}/portfolio-4-nosql/02_seed_data.js" "${TARGET_DIR}/${PREFIX}_P4_SeedData.js"
cp "${SRC}/portfolio-4-nosql/03_crud_and_aggregation.js" "${TARGET_DIR}/${PREFIX}_P4_CrudAndAggregation.js"
cp "${SRC}/portfolio-4-nosql/04_indexes_explain.js" "${TARGET_DIR}/${PREFIX}_P4_IndexesExplain.js"
cp "${SRC}/portfolio-4-nosql/output/03_crud_and_aggregation.txt" "${TARGET_DIR}/${PREFIX}_P4_Out_CrudAggregation.txt"
cp "${SRC}/portfolio-4-nosql/output/04_indexes_explain.txt" "${TARGET_DIR}/${PREFIX}_P4_Out_IndexesExplain.txt"
cp "${SRC}/portfolio-4-nosql/screenshots/01_schema_validation.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_SchemaValidation.png"
cp "${SRC}/portfolio-4-nosql/screenshots/02_seed_verification.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_SeedVerification.png"
cp "${SRC}/portfolio-4-nosql/screenshots/03_crud_output.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_CrudOutput.png"
cp "${SRC}/portfolio-4-nosql/screenshots/05_indexes_explain.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_IndexesExplain.png"
cp "${SRC}/portfolio-4-nosql/screenshots/06_ttl_result.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_TtlResult.png"
cp "${SRC}/portfolio-4-nosql/screenshots/07_compass_kyc_document.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_CompassKycDoc.png"
cp "${SRC}/portfolio-4-nosql/screenshots/08_compass_audit_event.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_CompassAuditEvent.png"
cp "${SRC}/portfolio-4-nosql/screenshots/09_compass_indexes.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_CompassIndexes.png"
cp "${SRC}/portfolio-4-nosql/screenshots/10_compass_validation.png" "${TARGET_DIR}/${PREFIX}_P4_Screen_CompassValidation.png"

echo "[6/6] Packaging Portfolio 5: Distributed & Cloud Databases..."
cp "${SRC}/portfolio-5-distributed-cloud/README.md" "${TARGET_DIR}/${PREFIX}_P5_README.md"
cp "${SRC}/portfolio-5-distributed-cloud/analysis.md" "${TARGET_DIR}/${PREFIX}_P5_DistributedAnalysis.md"
cp "${SRC}/portfolio-5-distributed-cloud/docker-compose.yml" "${TARGET_DIR}/${PREFIX}_P5_DockerCompose.yml"
cp "${SRC}/portfolio-5-distributed-cloud/replica-entrypoint.sh" "${TARGET_DIR}/${PREFIX}_P5_ReplicaEntrypoint.sh"
cp "${SRC}/portfolio-5-distributed-cloud/primary-init/01_replication.sh" "${TARGET_DIR}/${PREFIX}_P5_PrimaryInit.sh"
cp "${SRC}/portfolio-5-distributed-cloud/01_primary_checks.sql" "${TARGET_DIR}/${PREFIX}_P5_PrimaryChecks.sql"
cp "${SRC}/portfolio-5-distributed-cloud/02_replica_checks.sql" "${TARGET_DIR}/${PREFIX}_P5_ReplicaChecks.sql"
cp "${SRC}/portfolio-5-distributed-cloud/03_partitioning.sql" "${TARGET_DIR}/${PREFIX}_P5_Partitioning.sql"
cp "${SRC}/portfolio-5-distributed-cloud/04_atlas_cloud_check.js" "${TARGET_DIR}/${PREFIX}_P5_AtlasCloudCheck.js"
cp "${SRC}/portfolio-5-distributed-cloud/output/03_partitioning.txt" "${TARGET_DIR}/${PREFIX}_P5_Out_Partitioning.txt"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/01_docker_ps.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_DockerPs.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/02_row_counts.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_RowCounts.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/03_primary_checks.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_PrimaryChecks.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/04_replica_checks.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_ReplicaChecks.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/05_stale_read.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_StaleRead.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/06_caught_up.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_CaughtUp.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/07_sync_hang.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_SyncHang.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/08_sync_warning.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_SyncWarning.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/09_partitioning.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_Partitioning.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/10_failover.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_Failover.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/11_atlas_cluster.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_AtlasCluster.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/12_atlas_check_output.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_AtlasCheckOutput.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/freeze_the_replica.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_FreezeReplica.png"
cp "${SRC}/portfolio-5-distributed-cloud/screenshots/marker_table.png" "${TARGET_DIR}/${PREFIX}_P5_Screen_MarkerTable.png"

# Validation Phase: Check for spaces or generic filenames
echo "================================================================================"
echo " Validating Naming Constraints (NO SPACES, STRICT PREFIX)..."
echo "================================================================================"
SPACE_ERRORS=0
for f in "${TARGET_DIR}"/*; do
  BASENAME=$(basename "$f")
  if [[ "$BASENAME" =~ [[:space:]] ]]; then
    echo "ERROR: File contains spaces: $BASENAME"
    SPACE_ERRORS=$((SPACE_ERRORS + 1))
  fi
  if [[ ! "$BASENAME" =~ ^${PREFIX}_ ]]; then
    echo "ERROR: File does not start with ${PREFIX}_: $BASENAME"
    SPACE_ERRORS=$((SPACE_ERRORS + 1))
  fi
done

if [ "$SPACE_ERRORS" -gt 0 ]; then
  echo "Validation FAILED: $SPACE_ERRORS naming rule violations found!"
  exit 1
else
  echo "Validation PASSED: All $(ls -1 "${TARGET_DIR}" | wc -l | tr -d ' ') files strictly follow '${PREFIX}_DocumentType' with ZERO SPACES."
fi

# Zipping Phase
echo "================================================================================"
echo " Creating Zip Archive: ${ZIP_NAME}..."
echo "================================================================================"
zip -r -q "${ZIP_NAME}" "${TARGET_DIR}"

ZIP_SIZE_BYTES=$(wc -c < "${ZIP_NAME}" | tr -d ' ')
ZIP_SIZE_MB=$(echo "scale=2; $ZIP_SIZE_BYTES / (1024 * 1024)" | bc)

echo "Archive created successfully: ${ZIP_NAME}"
echo "Archive size: ${ZIP_SIZE_MB} MB (${ZIP_SIZE_BYTES} bytes)"

if (( $(echo "$ZIP_SIZE_MB > 100.0" | bc -l) )); then
  echo "WARNING: Archive exceeds the 100 MB Google Form upload limit!"
  exit 1
else
  echo "SUCCESS: Archive is well within the 100 MB upload limit (${ZIP_SIZE_MB} MB < 100 MB)."
fi

echo "================================================================================"
echo " Ready for LMS & Google Form Upload:"
echo " 1. Upload ${ZIP_NAME} to Google Form Field 2 (Zipped Folder)"
echo " 2. Upload ${PREFIX}_README.txt to Google Form Field 3 (ReadME File)"
echo "================================================================================"

