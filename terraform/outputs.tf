output "mlflow_ui" {
  description = "URL de la UI de MLflow"
  value       = "http://localhost:${var.mlflow_port}"
}

output "minio_console" {
  description = "URL de la consola de MinIO (user/pass: minioadmin/minioadmin por defecto)"
  value       = "http://localhost:${var.minio_console_port}"
}

output "tracking_uri" {
  description = "MLFLOW_TRACKING_URI para el script de training"
  value       = "http://localhost:${var.mlflow_port}"
}

output "serving_url" {
  description = "URL de la API REST del modelo servido (si enable_serving = true)"
  value       = var.enable_serving ? module.serving[0].serving_url : null
}
