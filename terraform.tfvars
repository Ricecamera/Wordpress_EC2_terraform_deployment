region            = "ap-southeast-1"
availability_zone = "ap-southeast-1a"
ami               = "ami-0d058fe428540cd89"
bucket_name       = "safetydolphinwalrus010"
database_name     = "wordpress"
database_user     = "username"
database_pass     = "password"
admin_user        = "admin"
admin_pass        = "admin"
ec2_instance_type = "t2.micro"
root_volume_size  = 22

PUBLIC_KEY_PATH   = "../key-pair/mykey-pair.pub"
PRIV_KEY_PATH     = "../key-pair/mykey-pair"