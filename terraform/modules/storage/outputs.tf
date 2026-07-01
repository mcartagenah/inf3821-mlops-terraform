output "network_name" {
  description = "Nombre de la red docker compartida por el stack"
  value       = docker_network.mlops.name
}

output "postgres_container_name" {
  description = "Nombre del contenedor de Postgres (para depends_on externo)"
  value       = docker_container.postgres.name
}

output "create_bucket_container_name" {
  description = "Nombre del contenedor init de creación de bucket (para depends_on externo)"
  value       = docker_container.create_bucket.name
}
