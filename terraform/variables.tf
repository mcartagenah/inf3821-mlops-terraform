variable "environment" {
  description = "Nombre del ambiente (dev / prod)"
  type        = string
  default     = "dev"
}

variable "mlflow_port" {
  description = "Puerto host para la UI de MLflow"
  type        = number
  default     = 5000
}

variable "minio_api_port" {
  description = "Puerto host para la API S3 de MinIO"
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Puerto host para la consola web de MinIO"
  type        = number
  default     = 9001
}

variable "minio_root_user" {
  description = "Usuario root de MinIO (= AWS_ACCESS_KEY_ID)"
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "Password root de MinIO (= AWS_SECRET_ACCESS_KEY)"
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

variable "postgres_password" {
  description = "Password de la base de datos de MLflow"
  type        = string
  default     = "mlflow"
  sensitive   = true
}

variable "artifact_bucket" {
  description = "Nombre del bucket S3 para artefactos de MLflow"
  type        = string
  default     = "mlflow-artifacts"
}

# ---------------------------------------------------------------------------
# TODO 5 — Model serving
# ---------------------------------------------------------------------------
variable "enable_serving" {
  description = "Si true, levanta el módulo de serving (TODO 5)"
  type        = bool
  default     = false
}

variable "serving_port" {
  description = "Puerto host para la API REST del modelo servido"
  type        = number
  default     = 5002
}

variable "serving_model_name" {
  description = "Nombre del modelo registrado en el Model Registry a servir"
  type        = string
  default     = "iris-clf"
}

variable "serving_model_version" {
  description = "Versión del modelo registrado a servir (correr train.py primero para generarla)"
  type        = string
  default     = "1"
}
