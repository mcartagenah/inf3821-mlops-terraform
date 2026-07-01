variable "environment" {
  description = "Nombre del ambiente (dev / prod)"
  type        = string
}

variable "network_name" {
  description = "Red docker compartida (creada por el módulo storage)"
  type        = string
}

variable "mlflow_port" {
  description = "Puerto host para la UI de MLflow"
  type        = number
}

variable "postgres_password" {
  description = "Password de la base de datos de MLflow"
  type        = string
  sensitive   = true
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

variable "artifact_bucket" {
  description = "Nombre del bucket S3 para artefactos de MLflow"
  type        = string
}
