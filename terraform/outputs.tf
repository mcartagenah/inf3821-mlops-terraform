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
