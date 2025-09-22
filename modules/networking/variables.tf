# Networking Module Variables

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_endpoint_security_group_ids" {
  description = "Security group IDs for VPC endpoints"
  type        = list(string)
  default     = []
}
