variable "environment" {
  description = "Nombre del ambiente (dev / prod)"
  type        = string
}

variable "network_name" {
  description = "Red docker compartida (creada por el módulo storage)"
  type        = string
}

variable "serving_port" {
  description = "Puerto host donde queda expuesta la API REST del modelo servido"
  type        = number
}

variable "tracking_uri" {
  description = "MLFLOW_TRACKING_URI interno (nombre de servicio en la red docker), usado para resolver models:/"
  type        = string
}

variable "model_name" {
  description = "Nombre del modelo registrado en el Model Registry de MLflow"
  type        = string
}

variable "model_version" {
  description = "Versión del modelo registrado a servir"
  type        = string
}

variable "minio_root_user" {
  description = "Usuario root de MinIO (= AWS_ACCESS_KEY_ID), necesario para descargar el artefacto del modelo"
  type        = string
}

variable "minio_root_password" {
  description = "Password root de MinIO (= AWS_SECRET_ACCESS_KEY)"
  type        = string
  sensitive   = true
}
