############################################
# Outputs
############################################
output "api_base_url" {
  value       = aws_apigatewayv2_api.http.api_endpoint
  description = "Invoke with: GET/POST {api_base_url}/items"
}

output "dynamodb_table" {
  value = aws_dynamodb_table.table.name
}