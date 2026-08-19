output "application_url" {
  description = "URL pública de Saludo Cloud"
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "hello_url" {
  description = "URL del endpoint obligatorio /hello"
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}/hello"
}

output "health_url" {
  description = "URL del endpoint /health"
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}/health"
}
