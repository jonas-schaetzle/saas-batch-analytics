import os
from pathlib import Path

import boto3


def upload_file_to_s3(local_path: str, bucket: str, s3_key: str) -> None:
    s3 = boto3.client("s3")
    s3.upload_file(local_path, bucket, s3_key)
    print(f"Uploaded {local_path} to s3://{bucket}/{s3_key}")


if __name__ == "__main__":
    bucket = os.environ["S3_BUCKET_NAME"]

    local_file = Path("/opt/airflow/data/raw/customers.csv")
    s3_key = "raw/customers/customers.csv"

    upload_file_to_s3(
        local_path=str(local_file),
        bucket=bucket,
        s3_key=s3_key,
    )