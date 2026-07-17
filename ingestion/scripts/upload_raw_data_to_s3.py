import os
from pathlib import Path

import boto3
from ingestion_utils import compute_file_sha256, resolve_raw_data_dir, resolve_run_id


def upload_raw_files(local_dir: Path, bucket: str, run_id: str) -> None:
    s3 = boto3.client("s3")
    uploaded_files = 0

    for file_path in sorted(local_dir.glob("*.csv")):
        table_name = file_path.stem
        file_sha256 = compute_file_sha256(file_path)

        s3_key = (
            f"raw/{table_name}/"
            f"run_id={run_id}/"
            f"{file_path.name}"
        )

        print(f"Uploading {file_path} -> s3://{bucket}/{s3_key}")

        s3.upload_file(
            Filename=str(file_path),
            Bucket=bucket,
            Key=s3_key,
            ExtraArgs={
                "Metadata": {
                    "ingestion_run_id": run_id,
                    "source_file_name": file_path.name,
                    "file_sha256": file_sha256,
                }
            },
        )
        uploaded_files += 1

    print(
        "Completed S3 upload "
        f"for run_id={run_id} with {uploaded_files} file(s) from {local_dir}"
    )


if __name__ == "__main__":
    bucket_name = os.environ["S3_BUCKET_NAME"]
    raw_data_dir = resolve_raw_data_dir()
    run_id = resolve_run_id()

    upload_raw_files(
        local_dir=raw_data_dir,
        bucket=bucket_name,
        run_id=run_id,
    )
