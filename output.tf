output api_snap_collection_url {
    value = "https://${aws_api_gateway_rest_api.api_snap_collection.id}.execute-api.${var.aws_region}.amazonaws.com/"
}