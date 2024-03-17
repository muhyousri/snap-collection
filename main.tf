resource "aws_dynamodb_table" "collection" {
  name           = "snap-collection"
  depends_on =  [aws_lambda_function.add_card]
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "card_id"
  range_key      = ""

  attribute {
    name = "card_id"
    type = "S"
  }

  attribute {
    name = "card_name"
    type = "S"
  }

  attribute {
    name = "owned"
    type = "S"
  }

    global_secondary_index {
    name               = "GameTitleIndex"
    hash_key           = "card_name"
    range_key          = "owned"
    write_capacity     = 10
    read_capacity      = 10
    projection_type    = "INCLUDE"
    non_key_attributes = ["card_id"]
  }

  tags = {
    Name        = "project"
    Environment = "snap-collection"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


resource "aws_iam_policy_attachment" "lambda_ddb_role_policy_attachment" {
  name       = "lambda_ddb_role_policy_attachment"
  roles      = [aws_iam_role.iam_for_lambda.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}


data "archive_file" "add_cardzip" {
  type = "zip"
  source_file = "add_card.py"
  output_path = "add_card.zip"
}


data "archive_file" "remove_cardzip" {
  type = "zip"
  source_file = "remove_card.py"
  output_path = "remove_card.zip"
}

resource "aws_lambda_function" "add_card" {
  function_name = "lambda_function_add_card"
  role          = aws_iam_role.iam_for_lambda.arn
  filename   = data.archive_file.add_cardzip.output_path
  handler       = "add_card.lambda_handler"
  runtime = "python3.9"
  }


resource "aws_lambda_function" "remove_card" {
  function_name = "lambda_function_remove_card"
  role          = aws_iam_role.iam_for_lambda.arn
  filename   = data.archive_file.remove_cardzip.output_path
  handler       = "remove_card.lambda_handler"
  runtime = "python3.9"
  }

resource "aws_api_gateway_rest_api" "api_snap_collection" {
  name        = "snap_collection_api"
}

resource "aws_api_gateway_method" "add-card-method" {
  rest_api_id   = aws_api_gateway_rest_api.api_snap_collection.id
  resource_id   = aws_api_gateway_resource.add-card.id
  http_method   = "POST" 
  authorization = "NONE" 
}

resource "aws_api_gateway_resource" "add-card" {
  rest_api_id = aws_api_gateway_rest_api.api_snap_collection.id
  parent_id   = aws_api_gateway_rest_api.api_snap_collection.root_resource_id
  path_part   = "add-card" 
}



resource "aws_api_gateway_integration" "integration_add" {
  rest_api_id             = aws_api_gateway_rest_api.api_snap_collection.id
  resource_id             = aws_api_gateway_resource.add-card.id
  http_method             = aws_api_gateway_method.add-card-method.http_method
  integration_http_method = "POST"  # Specify the HTTP method for the integration
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.add_card.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_permission_add" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_card.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${aws_api_gateway_rest_api.api_snap_collection.id}/*/*"
}

#### remove 

resource "aws_api_gateway_resource" "remove-card" {
  rest_api_id = aws_api_gateway_rest_api.api_snap_collection.id
  parent_id   = aws_api_gateway_rest_api.api_snap_collection.root_resource_id
  path_part   = "remove-card" 
}

resource "aws_api_gateway_method" "remove-card-method" {
  rest_api_id   = aws_api_gateway_rest_api.api_snap_collection.id
  resource_id   = aws_api_gateway_resource.remove-card.id
  http_method   = "POST" 
  authorization = "NONE" 
}

resource "aws_api_gateway_integration" "integration_remove" {
  rest_api_id             = aws_api_gateway_rest_api.api_snap_collection.id
  resource_id             = aws_api_gateway_resource.remove-card.id
  http_method             = aws_api_gateway_method.remove-card-method.http_method
  integration_http_method = "POST"  # Specify the HTTP method for the integration
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.remove_card.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_permission_remove" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remove_card.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${aws_api_gateway_rest_api.api_snap_collection.id}/*/*"
}



resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_snap_collection.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.add-card.id,
      aws_api_gateway_resource.remove-card.id,
      aws_api_gateway_method.add-card-method.id,
      aws_api_gateway_method.remove-card-method.id,
      aws_api_gateway_integration.integration_add.id,
      aws_api_gateway_integration.integration_remove.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "test_stage" {
  stage_name    = "dev"
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_snap_collection.id
}
