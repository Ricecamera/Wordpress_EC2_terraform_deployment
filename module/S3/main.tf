resource "aws_s3_bucket" "my_bucket" {
  bucket        = "${var.prefix}-${var.name}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "my_bucket_public_access" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_policy     = true
  restrict_public_buckets = true
}