output "serving_url" {
  description = "URL de la API REST del modelo servido"
  value       = "http://localhost:${var.serving_port}/invocations"
}
