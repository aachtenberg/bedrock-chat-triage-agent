import json
import os

import boto3


client = boto3.client("bedrock-agent-runtime")
knowledge_base_id = os.environ["KNOWLEDGE_BASE_ID"]
default_result_count = int(os.environ.get("SEARCH_RESULTS", "5"))


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body),
    }


def handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "Body must be valid JSON."})

    query = (payload.get("query") or payload.get("message") or "").strip()
    limit = int(payload.get("limit") or default_result_count)

    if not query:
        return response(400, {"error": "query is required."})

    try:
        result = client.retrieve(
            knowledgeBaseId=knowledge_base_id,
            retrievalQuery={"text": query},
            retrievalConfiguration={
                "vectorSearchConfiguration": {
                    "numberOfResults": limit,
                }
            },
        )
    except Exception as exc:
        return response(500, {"error": f"Knowledge base search failed: {exc}"})

    items = []
    for item in result.get("retrievalResults", []):
        location = item.get("location", {})
        s3_location = location.get("s3Location", {})
        items.append(
            {
                "score": item.get("score"),
                "uri": s3_location.get("uri"),
                "text": item.get("content", {}).get("text", "")[:500],
                "metadata": item.get("metadata", {}),
            }
        )

    return response(200, {"results": items})
