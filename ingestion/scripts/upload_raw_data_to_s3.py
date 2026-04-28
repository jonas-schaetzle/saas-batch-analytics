import os
from pathlib import Path

import boto3


def upload_directory_to_s3(local_dir: str, bucket: str, prefix: str):
    s3 = boto3.client("s3")

    base_path = Path(local_dir)

    for file_path in base_path.glob("*.csv"):
        s3_key = f"{prefix}/{file_path.stem}/{file_path.name}"

        print(f"Uploading {file_path} → s3://{bucket}/{s3_key}")

        s3.upload_file(
            Filename=str(file_path),
            Bucket=bucket,
            Key=s3_key,
        )


if __name__ == "__main__":
    bucket_name = os.environ["S3_BUCKET_NAME"]

    upload_directory_to_s3(
        local_dir="/opt/airflow/data/raw",
        bucket=bucket_name,
        prefix="raw",
    )