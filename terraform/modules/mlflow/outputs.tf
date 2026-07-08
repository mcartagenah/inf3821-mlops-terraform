output "container_name" {
  description = "Nombre del contenedor de MLflow (para depends_on externo, ej. serving)"
  value       = docker_container.mlflow.name
}

output "tracking_uri" {
  description = "MLFLOW_TRACKING_URI accesible desde el host"
  value       = "http://localhost:${var.mlflow_port}"
}
