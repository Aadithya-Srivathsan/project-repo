import os
import logging

import azure.functions as func
from openai import AzureOpenAI

# Create Function App (anonymous so you can call it easily from web/JS)
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Azure OpenAI client from environment variables (we’ll set these in Terraform)
client = AzureOpenAI(
    api_key=os.environ["AZURE_OPENAI_API_KEY"],
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_version=os.environ.get("AZURE_OPENAI_API_VERSION", "2025-03-01-preview"),
)

DEPLOYMENT_NAME = os.environ["AZURE_OPENAI_DEPLOYMENT"]  # e.g. gpt-4o-deployment


@app.function_name(name="ChatHttpTrigger")
@app.route(route="chat", methods=["GET", "POST"])
def chat(req: func.HttpRequest) -> func.HttpResponse:
    """
    Simple web GPT endpoint.

    GET  /api/chat?q=hello
    POST /api/chat  {"message": "hello"}
    """

    logging.info("Chat HTTP trigger function processed a request.")

    # Get user message from query or JSON body
    query_msg = req.params.get("q")
    body_msg = None

    try:
        if not query_msg and req.get_body():
            body_json = req.get_json()
            body_msg = body_json.get("message")
    except ValueError:
        # Invalid JSON body
        pass

    user_message = query_msg or body_msg
    if not user_message:
        return func.HttpResponse(
            "Please send your prompt via ?q=... or JSON body {\"message\":\"...\"}",
            status_code=400,
        )

    # Call Azure OpenAI chat completions
    try:
        response = client.chat.completions.create(
            model=DEPLOYMENT_NAME,
            messages=[
                {
                    "role": "system",
                    "content": "You are a helpful web-based GPT assistant.",
                },
                {"role": "user", "content": user_message},
            ],
            temperature=0.7,
        )

        answer = response.choices[0].message.content
        return func.HttpResponse(
            answer,
            status_code=200,
            headers={"Content-Type": "text/plain; charset=utf-8"},
        )

    except Exception as e:
        logging.exception("Error calling Azure OpenAI")
        return func.HttpResponse(
            f"Error from Azure OpenAI: {e}", status_code=500
        )
