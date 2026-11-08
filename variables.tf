variable "aws_region" {
  description = "Region de AWS donde se despliega la evidencia"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo usado para nombrar todos los recursos de este PoC"
  type        = string
  default     = "aws-servicios"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.project_name)) && length(var.project_name) >= 3 && length(var.project_name) <= 30
    error_message = "project_name debe tener entre 3 y 30 caracteres, usando solo minúsculas, números y guiones."
  }
}
