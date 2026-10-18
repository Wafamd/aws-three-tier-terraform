variable "project" {
  description = "Short name used as a prefix for every resource."
  type        = string
  default     = "threetier"
}

variable "environment" {
  description = "Environment name (dev/stage/prod)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

# ---------- Networking ----------

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a /16 for the subnet math below."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "How many Availability Zones to spread across (2 or 3)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT GW (cheap, single point of failure). false = one per AZ."
  type        = bool
  default     = true
}

variable "ingress_cidrs" {
  description = "CIDRs allowed to reach the load balancer. Lock this down for non-public apps."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------- Web tier ----------

variable "instance_type" {
  description = "EC2 instance type for the web/app tier."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "cpu_target_utilization" {
  description = "Target-tracking scaling target for average CPU (percent)."
  type        = number
  default     = 50
}

variable "certificate_arn" {
  description = "ACM certificate ARN. If set, an HTTPS listener is created and HTTP redirects to it."
  type        = string
  default     = ""
}

# ---------- Data tier ----------

variable "db_engine" {
  type    = string
  default = "mysql"
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_multi_az" {
  description = "Multi-AZ standby. Roughly doubles RDS cost; leave true for prod."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  description = "Protect the RDS instance from accidental destroy."
  type        = bool
  default     = false
}
