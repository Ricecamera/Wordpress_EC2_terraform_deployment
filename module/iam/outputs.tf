output "secret" {
  value = aws_iam_access_key.lb.secret
}

output "access_key" {
  value = aws_iam_access_key.lb.id
}