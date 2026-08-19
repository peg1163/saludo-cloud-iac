variable "subscription_id" {
  description = "Identificador de la suscripción de Azure"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Región de Azure donde se crearán los recursos"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-saludo-cloud"
}

variable "log_analytics_workspace_name" {
  description = "Nombre del workspace de Log Analytics"
  type        = string
  default     = "law-saludo-cloud"
}

variable "container_app_environment_name" {
  description = "Nombre del entorno de Azure Container Apps"
  type        = string
  default     = "cae-saludo-cloud"
}

variable "container_app_name" {
  description = "Nombre de la aplicación en Azure Container Apps"
  type        = string
  default     = "ca-saludo-cloud"
}

variable "container_image" {
  description = "Imagen pública que ejecutará Container Apps"
  type        = string
  default     = "docker.io/peg1163/saludo-cloud:v1"
}

variable "student_name" {
  description = "Nombre que devuelve el endpoint /hello"
  type        = string
  default     = "Jaime ACuña"
}

variable "min_replicas" {
  description = "Cantidad mínima de réplicas"
  type        = number
  default     = 1

  validation {
    condition     = var.min_replicas >= 1
    error_message = "min_replicas debe ser al menos 1."
  }
}

variable "max_replicas" {
  description = "Cantidad máxima de réplicas"
  type        = number
  default     = 3

  validation {
    condition     = var.max_replicas >= 1
    error_message = "max_replicas debe ser al menos 1."
  }
}
