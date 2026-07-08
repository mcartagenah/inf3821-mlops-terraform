variable "environment" {
  description = "Nombre del ambiente (dev / prod)"
  type        = string
}

variable "minio_api_port" {
  description = "Puerto host para la API S3 de MinIO"
  type        = number
}

variable "minio_console_port" {
  description = "Puerto host para la consola web de MinIO"
  type        = number
}

variable "minio_root_user" {
  description = "Usuario root de MinIO (= AWS_ACCESS_KEY_ID)"
  type        = string
}

variable "minio_root_password" {
  description = "Password root de MinIO (= AWS_SECRET_ACCESS_KEY)"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Password de la base de datos de MLflow"
  type        = string
  sensitive   = true
}

variable "artifact_bucket" {
  description = "Nombre del bucket S3 para artefactos de MLflow"
  type        = string
}
