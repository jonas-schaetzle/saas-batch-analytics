import os
from datetime import datetime, timezone
from pathlib import Path

import boto3


def upload_raw_files(local_dir: str, bucket: str) -> None:
    s3 = boto3.client("s3")

    load_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    base_path = Path(local_dir)

    for file_path in base_path.glob("*.csv"):
        table_name = file_path.stem

        s3_key = (
            f"raw/{table_name}/"
            f"load_date={load_date}/"
            f"{file_path.name}"
        )

        print(f"Uploading {file_path} -> s3://{bucket}/{s3_key}")

        s3.upload_file(
            Filename=str(file_path),
            Bucket=bucket,
            Key=s3_key,
        )


if __name__ == "__main__":
    bucket_name = os.environ["S3_BUCKET_NAME"]

    upload_raw_files(
        local_dir="/opt/airflow/data/raw",
        bucket=bucket_name,
    )