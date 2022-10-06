resource "aws_iam_access_key" "lb" {
  user    = aws_iam_user.lb.name
}

resource "aws_iam_user" "lb" {
  name = "wp-s3-user"
  path = "/system/"
}

resource "aws_iam_user_policy" "lb_ro" {
  name = "wp-s3-policy"
  user = aws_iam_user.lb.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObjectAcl",
                "s3:GetObject",
                "s3:PutBucketAcl",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::${var.s3_bucket}",
                "arn:aws:s3:::${var.s3_bucket}/*"
            ]
        }
    ]
}
EOF
}
