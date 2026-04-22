provider "aws" {
  region = var.aws_region
}

# ----------------------------
# S3 Bucket
# ----------------------------
resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name

  tags = {
    project = "saas-batch-analytics"
  }
}

# ----------------------------
# IAM User
# ----------------------------
resource "aws_iam_user" "data_user" {
  name = "saas-data-user"
}

# ----------------------------
# IAM Policy (S3 Zugriff)
# ----------------------------
resource "aws_iam_policy" "s3_access" {
  name = "saas-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# ----------------------------
# Policy an User hängen
# ----------------------------
resource "aws_iam_user_policy_attachment" "attach_policy" {
  user       = aws_iam_user.data_user.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# ----------------------------
# Access Keys erzeugen
# ----------------------------
resource "aws_iam_access_key" "access_key" {
  user = aws_iam_user.data_user.name
}