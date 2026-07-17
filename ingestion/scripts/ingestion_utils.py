import hashlib
import os
from datetime import datetime, timezone
from pathlib import Path


def resolve_run_id() -> str:
    return os.getenv(
        "INGESTION_RUN_ID",
        datetime.now(timezone.utc).strftime("manual__%Y%m%dT%H%M%SZ"),
    )


def resolve_raw_data_dir() -> Path:
    return Path(os.getenv("RAW_DATA_DIR", "/opt/airflow/data/raw"))


def compute_file_sha256(file_path: Path) -> str:
    digest = hashlib.sha256()

    with file_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()
