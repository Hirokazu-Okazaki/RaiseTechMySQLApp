terraform {
  required_version = ">= 0.12.0"
  backend "s3" {
    bucket = "terraform-state-raisetech-okazaki"
    region = "ap-northeast-1"
    key = "terraform.tfstate"
    encrypt = true
  }
}

# VPC
resource aws_vpc this {
  cidr_block            = "10.0.0.0/16"
  instance_tenancy      = "default"
  enable_dns_support    = true
  enable_dns_hostnames  = true

  tags = {
    Name = "tf.aws_vpc.this"
  }
}

# Subnet
resource aws_subnet public_1a {
  depends_on              = [aws_vpc.this]
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf.aws_subnet.public_1a"
  }
}

resource aws_subnet public_1c {
  depends_on              = [aws_vpc.this]
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "tf.aws_subnet.public_1c"
  }
}

resource aws_subnet private_1a {
  depends_on        = [aws_vpc.this]
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "tf.aws_subnet.private_1a"
  }
}

resource aws_subnet private_1c {
  depends_on        = [aws_vpc.this]
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "tf.aws_subnet.private_1c"
  }
}

# InternetGateway
resource aws_internet_gateway this {
  depends_on  = [aws_vpc.this]
  vpc_id      = aws_vpc.this.id
  
  tags = {
    Name = "tf.aws_internet_gateway.this"
  }
}

# RouteTable
resource aws_route_table public {
  depends_on  = [aws_internet_gateway.this]
  vpc_id      = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "tf.aws_route_table.public"
  }
}

# RouteTableAssociation
resource aws_route_table_association public_1a {
  depends_on      = [aws_subnet.public_1a]
  subnet_id       = aws_subnet.public_1a.id
  route_table_id  = aws_route_table.public.id
}

resource aws_route_table_association public_1c {
  depends_on      = [aws_subnet.public_1c]
  subnet_id       = aws_subnet.public_1c.id
  route_table_id  = aws_route_table.public.id
}

# SecurityGroup ALB
resource aws_security_group alb {
  depends_on  = [aws_vpc.this]
  vpc_id      = aws_vpc.this.id
  name        = "tf.aws_security_group.alb"
  description = "Allow http and https traffic."
}

# SecurityGroupRule Allow 80 port
resource aws_security_group_rule inbound_alb_http {
  depends_on          = [aws_security_group.alb]
  security_group_id   = aws_security_group.alb.id
  type                = "ingress"
  from_port           = 80
  to_port             = 80
  protocol            = "tcp"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

# SecurityGroupRule Allow 443 port
resource aws_security_group_rule inbound_alb_https {
  depends_on          = [aws_security_group.alb]
  security_group_id   = aws_security_group.alb.id
  type                = "ingress"
  from_port           = 443
  to_port             = 443
  protocol            = "tcp"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

# SecurityGroupRule egress
resource aws_security_group_rule outbound_alb {
  depends_on          = [aws_security_group.alb]
  security_group_id   = aws_security_group.alb.id
  type                = "egress"
  from_port           = 0
  to_port             = 0
  protocol            = "-1"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

data aws_elb_service_account this {}

# S3
resource aws_s3_bucket lb_logs {
  bucket  = "tf-raisetech-accesslog-bucket"
  acl     = "private"
  region  = "ap-northeast-1"

  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::tf-raisetech-accesslog-bucket/*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.this.arn}"
        ]
      }
    }
  ]
}
POLICY
  
  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "tf-raisetech-accesslog-bucket"
  }
}

resource aws_s3_bucket_public_access_block lb_logs {
  bucket = aws_s3_bucket.lb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ApplicationLoadBalancer
resource aws_lb this {
  depends_on  = [
    aws_security_group.alb,
    aws_subnet.public_1a,
    aws_subnet.public_1c,
    aws_s3_bucket.lb_logs,
  ]

  load_balancer_type          = "application"
  name                        = "tf-aws-lb"
  internal                    = false
  enable_deletion_protection  = false
  security_groups             = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.public_1a.id, 
    aws_subnet.public_1c.id,
  ]
 
  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    enabled = true
  }
}

# ALB TargetGroup
resource aws_alb_target_group this {
  depends_on  = [aws_lb.this]
  name        = "tf-aws-alb-target-group-this"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
 
  health_check {
    interval            = 30
    path                = "/index.html"
    port                = 80
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
    matcher             = 200
  }
}

# ALB TargetGroupAttachment
resource aws_alb_target_group_attachment this {
  depends_on = [
    aws_alb_target_group.this,
    aws_instance.app_1a,
  ]

  target_group_arn = aws_alb_target_group.this.arn
  target_id        = aws_instance.app_1a.id
  port             = 80
}

# ALB Listener
resource aws_lb_listener http {
  depends_on        = [aws_alb_target_group.this]
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource aws_lb_listener https {
  depends_on = [
    aws_alb_target_group.this,
    aws_acm_certificate.this,
  ]

  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.this.arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.this.arn
  }
}

# ACM
resource aws_acm_certificate this {
  domain_name         = "*.raisetechportfolio.tk"
  validation_method   = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_acm_certificate_validation this {
  depends_on = [
    aws_acm_certificate.this,
    aws_route53_record.cert_validation
  ]

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

# Route53
resource aws_route53_zone this {
  name = "raisetechportfolio.tk"
}

resource aws_route53_record cert_validation {
  depends_on = [
    aws_route53_zone.this,
    aws_acm_certificate.this
  ]

  zone_id = aws_route53_zone.this.zone_id
  name    = aws_acm_certificate.this.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.this.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.this.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource aws_route53_record www {
  depends_on = [
    aws_route53_zone.this,
    aws_lb.this
  ]

  zone_id = aws_route53_zone.this.zone_id
  name    = "www.raisetechportfolio.tk"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
 
# SecurityGroup RDS
resource aws_security_group db {
  depends_on  = [aws_vpc.this]
  vpc_id      = aws_vpc.this.id
  name        = "tf.aws_security_group.db"
  description = "Allow RDS traffic."
}

# SecurityGroupRule Allow 3306 port
resource aws_security_group_rule inbound_db {
  depends_on                = [aws_security_group.db]
  security_group_id         = aws_security_group.db.id
  type                      = "ingress"
  from_port                 = 3306
  to_port                   = 3306
  protocol                  = "tcp"
  source_security_group_id  = aws_security_group.ec2.id
}

# SecurityGroupRule egress
resource aws_security_group_rule outbound_db {
  depends_on          = [aws_security_group.db]
  security_group_id   = aws_security_group.db.id
  type                = "egress"
  from_port           = 0
  to_port             = 0
  protocol            = "-1"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

# RDS
resource aws_db_instance this {
  depends_on = [
    aws_security_group.db,
    aws_db_subnet_group.this,
    aws_ssm_parameter.db_username,
    aws_ssm_parameter.db_password,
  ]

  identifier                = "tfdbinstance"
  allocated_storage         = 20
  storage_type              = "gp2"
  engine                    = "mysql"
  engine_version            = "5.7"
  instance_class            = "db.t2.micro"
  name                      = "tfdb"
  username                  = aws_ssm_parameter.db_username.value
  password                  = aws_ssm_parameter.db_password.value
  parameter_group_name      = "default.mysql5.7"
  vpc_security_group_ids    = [aws_security_group.db.id]
  db_subnet_group_name      = aws_db_subnet_group.this.name
  backup_retention_period   = "1"
  apply_immediately         = "true"
  skip_final_snapshot       = true
  final_snapshot_identifier = "tffinalidentifier"
}

resource aws_db_subnet_group this {
  name        = "tf_dbsubnet"
  description = "It is a DB subnet group on tf_vpc."

  subnet_ids  = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1c.id,
  ]
}

# RDS DB_User ユーザー名をパラメータ登録する（暗号化なし）
resource aws_ssm_parameter db_username {
  name  = "/org/repo/dev/DB_USERNAME"
  value = "RaiseTechUser"
  type  = "String"
}

# RDS DB_Password 16文字のパスワードを自動生成
resource random_password db_password {
  length           = 16
  special          = true
  override_special = "_%@"
}

# RDS DB_Password 生成したパスワードをパラメータ登録する（暗号化あり）
resource aws_ssm_parameter db_password {
  name  = "/org/repo/dev/DB_PASSWORD"
  value = random_password.db_password.result
  type  = "SecureString"
}

# SecurityGroup EC2
resource aws_security_group ec2 {
  depends_on  = [aws_vpc.this]
  vpc_id      = aws_vpc.this.id
  name        = "tf.aws_security_group.ec2"
  description = "Allow http and https traffic."
}

# SecurityGroupRule Allow 22 port
resource aws_security_group_rule inbound_ec2_ssh {
  depends_on          = [aws_security_group.ec2]
  security_group_id   = aws_security_group.ec2.id
  type                = "ingress"
  from_port           = 22
  to_port             = 22
  protocol            = "tcp"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

# SecurityGroupRule Allow 80 port
resource aws_security_group_rule inbound_ec2_http {
  depends_on          = [aws_security_group.ec2]
  security_group_id   = aws_security_group.ec2.id
  type                = "ingress"
  from_port           = 80
  to_port             = 80
  protocol            = "tcp"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

# SecurityGroupRule egress
resource aws_security_group_rule outbound_ec2 {
  depends_on          = [aws_security_group.ec2]
  security_group_id   = aws_security_group.ec2.id
  type                = "egress"
  from_port           = 0
  to_port             = 0
  protocol            = "-1"
  cidr_blocks         = ["0.0.0.0/0"]
  ipv6_cidr_blocks    = ["::/0"]
}

# EC2
resource aws_instance app_1a {
  ami                     = "ami-03221ff557052673d"
  availability_zone       = "ap-northeast-1a"
  subnet_id               = aws_subnet.public_1a.id
  instance_type           = "t2.small"
  vpc_security_group_ids  = [aws_security_group.ec2.id]

  tags = {
    Name = "tf.aws_instance.app_1a"
  }
}