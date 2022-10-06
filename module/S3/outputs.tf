output "bucket_id" {
  value = aws_s3_bucket.my_bucket.id
}

output "bucket_name" {
  value = aws_s3_bucket.my_bucket.bucket
}

output "bucket_region" {
  value = aws_s3_bucket.my_bucket.region
}