# Automate Lambda packaging
resource "null_resource" "zip_lambda" {
  triggers = {
    src_hash = filesha256("lambda_function.py")
  }
  provisioner "local-exec" {
    command = "zip function.zip lambda_function.py"
  }
}

locals {
  name = "burmanic-sls-demo"
  tags = {
    Project = local.name
    Owner   = "coolteddy"
    Env     = "demo"
  }
}

############################################
# DynamoDB
############################################
resource "aws_dynamodb_table" "table" {
  name         = "${local.name}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  tags = local.tags
}

############################################
# Lambda (Python 3.12) + Logs
############################################
# Inline handler that supports GET (read) and POST (write)


resource "aws_cloudwatch_log_group" "lambda_lg" {
  name              = "/aws/lambda/${local.name}-fn"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_inline" {
  name = "${local.name}-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Logs
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream","logs:PutLogEvents"],
        Resource = "${aws_cloudwatch_log_group.lambda_lg.arn}:*"
      },
      # DynamoDB least-privilege
      {
        Effect = "Allow",
        Action = ["dynamodb:PutItem","dynamodb:GetItem"],
        Resource = aws_dynamodb_table.table.arn
      }
    ]
  })
}

resource "aws_lambda_function" "fn" {
  function_name = "${local.name}-fn"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  filename      = "function.zip"
  source_code_hash = filebase64sha256("function.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.table.name
    }
  }

  depends_on = [null_resource.zip_lambda, aws_cloudwatch_log_group.lambda_lg]
  tags       = local.tags
}

############################################
# API Gateway HTTP API → Lambda
############################################
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn.arn
  payload_format_version = "2.0"
}

# Route handles /items with ANY (GET/POST supported in code)
resource "aws_apigatewayv2_route" "items" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

# Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}


