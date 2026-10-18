data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /16 split into /24s:
  #   public  -> 10.0.0.x, 10.0.1.x   (ALB, NAT)
  #   app     -> 10.0.10.x, 10.0.11.x (EC2)
  #   data    -> 10.0.20.x, 10.0.21.x (RDS)
  public_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  app_subnets    = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  data_subnets   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 20)]

  nat_count = var.single_nat_gateway ? 1 : var.az_count
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# ---------- Subnets ----------

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.app_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.name}-app-${local.azs[count.index]}"
    Tier = "private-app"
  }
}

resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.data_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.name}-data-${local.azs[count.index]}"
    Tier = "private-data"
  }
}

# ---------- NAT ----------

resource "aws_eip" "nat" {
  count      = local.nat_count
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = { Name = "${local.name}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.this]

  tags = { Name = "${local.name}-nat-${count.index}" }
}

# ---------- Routing ----------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-public" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ so each can point at its own NAT when HA is on.
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private-${local.azs[count.index]}" }
}

resource "aws_route" "private_default" {
  count                  = var.az_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "app" {
  count          = var.az_count
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Data subnets get no internet route at all.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-data" }
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# Gateway endpoint: S3 traffic from private subnets skips the NAT (and the NAT bill).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, [aws_route_table.data.id])

  tags = { Name = "${local.name}-vpce-s3" }
}
