provider "aws" {
  region = "eu-west-1"
}


resource "aws_dynamodb_table" "VoffGPS" {
  name         = "VoffGPS"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key    = "created"

  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "created"
    type = "S"
  }
}

# --- LAMBDA -----------

resource "aws_iam_role" "role" {
  name               = "role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "policy" {
  name   = "role"
  role   = "${aws_iam_role.role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "cloudformation:DescribeChangeSet",
          "cloudformation:DescribeStackResources",
          "cloudformation:DescribeStacks",
          "cloudformation:GetTemplate",
          "cloudformation:ListStackResources",
          "cloudwatch:*",
          "cognito-identity:ListIdentityPools",
          "cognito-sync:GetCognitoEvents",
          "cognito-sync:SetCognitoEvents",
          "dynamodb:*",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "events:*",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListRoles",
          "iam:PassRole",
          "iot:AttachPrincipalPolicy",
          "iot:AttachThingPrincipal",
          "iot:CreateKeysAndCertificate",
          "iot:CreatePolicy",
          "iot:CreateThing",
          "iot:CreateTopicRule",
          "iot:DescribeEndpoint",
          "iot:GetTopicRule",
          "iot:ListPolicies",
          "iot:ListThings",
          "iot:ListTopicRules",
          "iot:ReplaceTopicRule",
          "kinesis:DescribeStream",
          "kinesis:ListStreams",
          "kinesis:PutRecord",
          "kms:ListAliases",
          "lambda:*",
          "logs:*",
          "s3:*",
          "sns:ListSubscriptions",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTopics",
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sqs:ListQueues",
          "sqs:SendMessage",
          "tag:GetResources",
          "xray:PutTelemetryRecords",
          "xray:PutTraceSegments"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "gps" {
  filename         = ".serverless/gps.zip"
  function_name    = "gps"
  role             = "${aws_iam_role.role.arn}"
  handler          = "src/handler.handler"
  source_code_hash = "${filebase64sha256(".serverless/gps.zip")}"
  timeout          = 30
  runtime          = "nodejs10.x"
  memory_size      = 1536
}

# ---- API GATEWAY ------
resource "aws_api_gateway_rest_api" "gps" {
  name        = "gps"
  description = "gps rest api gateway"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.gps.id}"
  parent_id   = "${aws_api_gateway_rest_api.gps.root_resource_id}"
  path_part   = "gps"
}
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.gps.id}"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  http_method   = "ANY"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.gps.id}"
  resource_id = "${aws_api_gateway_resource.proxy.id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "${aws_lambda_function.gps.invoke_arn}"
}

resource "aws_api_gateway_deployment" "gps" {
  depends_on = [
    "aws_api_gateway_integration.lambda"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.gps.id}"
  stage_name  = "v1"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.gps.arn}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_deployment.gps.execution_arn}/*/*"
}
