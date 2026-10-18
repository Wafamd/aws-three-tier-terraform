# Tier 1: load balancer — the only thing exposed to the internet.
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Ingress from the internet to the ALB"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${local.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count             = length(var.ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.ingress_cidrs[count.index]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = var.certificate_arn == "" ? 0 : length(var.ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.ingress_cidrs[count.index]
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Tier 2: app servers — reachable only from the ALB.
resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "App tier, ingress from ALB only"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${local.name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Tier 3: database — reachable only from the app tier.
resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "Database tier, ingress from app tier only"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${local.name}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = local.db_port
  to_port                      = local.db_port
  ip_protocol                  = "tcp"
}
