import os, json, boto3
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    if method == "POST":
        body = json.loads(event.get("body") or "{}")
        item = {"pk": body.get("id", "id-"+context.aws_request_id), **body}
        table.put_item(Item=item)
        return {"statusCode": 201, "headers": {"Content-Type":"application/json"}, "body": json.dumps(item)}
    else:  # GET
        from urllib.parse import parse_qs
        q = parse_qs(event.get("rawQueryString") or "")
        pk = (q.get("id") or ["sample"])[0]
        resp = table.get_item(Key={"pk": pk})
        return {"statusCode": 200, "headers": {"Content-Type":"application/json"}, "body": json.dumps(resp.get("Item") or {"message":"not found","pk":pk})}
