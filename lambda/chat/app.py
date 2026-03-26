import json
import os
import uuid

import boto3


client = boto3.client("bedrock-agent-runtime")
agent_id = os.environ["AGENT_ID"]
agent_alias_id = os.environ["AGENT_ALIAS_ID"]
knowledge_base_id = os.environ["KNOWLEDGE_BASE_ID"]
search_results = int(os.environ.get("SEARCH_RESULTS", "5"))


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body),
    }


def collect_sources(citations):
    sources = []

    for citation in citations or []:
        for reference in citation.get("retrievedReferences", []):
            location = reference.get("location", {})
            s3_location = location.get("s3Location", {})
            metadata = reference.get("metadata", {})
            snippet = reference.get("content", {}).get("text", "")

            sources.append(
                {
                    "uri": s3_location.get("uri"),
                    "score": reference.get("score"),
                    "snippet": snippet[:400],
                    "metadata": metadata,
                }
            )

    deduped = []
    seen = set()
    for source in sources:
        key = (source.get("uri"), source.get("snippet"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(source)

    return deduped


def invoke_error(event):
    for key in (
        "accessDeniedException",
        "badGatewayException",
        "conflictException",
        "dependencyFailedException",
        "internalServerException",
        "modelNotReadyException",
        "resourceNotFoundException",
        "serviceQuotaExceededException",
        "throttlingException",
        "validationException",
    ):
        details = event.get(key)
        if details:
            return details.get("message") or key
    return None


def handler(event, context):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "Body must be valid JSON."})

    prompt = (payload.get("message") or payload.get("prompt") or "").strip()
    session_id = payload.get("session_id") or str(uuid.uuid4())

    if not prompt:
        return response(400, {"error": "message is required."})

    request = {
        "agentAliasId": agent_alias_id,
        "agentId": agent_id,
        "inputText": prompt,
        "sessionId": session_id,
        "sessionState": {
            "knowledgeBaseConfigurations": [
                {
                    "knowledgeBaseId": knowledge_base_id,
                    "retrievalConfiguration": {
                        "vectorSearchConfiguration": {
                            "numberOfResults": search_results,
                        }
                    },
                },
            ]
        },
    }

    try:
        result = client.invoke_agent(**request)
    except Exception as exc:
        return response(500, {"error": f"Bedrock request failed: {exc}"})

    answer_parts = []
    citations = []

    for event in result.get("completion", []):
        message = invoke_error(event)
        if message:
            return response(500, {"error": f"Bedrock request failed: {message}"})

        chunk = event.get("chunk")
        if not chunk:
            continue

        answer_parts.append(chunk.get("bytes", b"").decode("utf-8"))
        citations.extend(chunk.get("attribution", {}).get("citations", []))

    return response(
        200,
        {
            "answer": "".join(answer_parts).strip(),
            "session_id": result.get("sessionId", session_id),
            "sources": collect_sources(citations),
        },
    )
