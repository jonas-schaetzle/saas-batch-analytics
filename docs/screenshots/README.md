# Screenshot Guide

This folder is reserved for reviewer-facing screenshots referenced from the main project README.

Recommended files:

- `01_pipeline_health.png`
- `02_churn_analysis.png`
- `03_airflow_ingestion_dag.png`
- `04_airflow_transformation_dag.png`
- `05_dbt_lineage.png`

Suggested capture order:

1. run `make demo`
2. capture `mart_pipeline_health`
3. capture `mart_churn_analysis`
4. capture both Airflow DAG graph views
5. run `make dbt-docs` and capture the lineage view

Capture guidance:

- crop tightly to the relevant content
- keep browser or terminal chrome minimal
- prefer readable dark-mode or light-mode contrast
- avoid oversized full-screen captures when a focused crop is clearer

Once the real images are added, the placeholders in the top-level `README.md` will resolve automatically.

