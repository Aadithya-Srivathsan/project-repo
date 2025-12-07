import os
import logging
import azure.functions as func
from openai import AzureOpenAI

# HTTP function app with anonymous access
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Load config from environment variables (KeyVault ready)
AZURE_ENDPOINT = os.environ.get("AZURE_OPENAI_ENDPOINT")
AZURE_API_KEY = os.environ.get("AZURE_OPENAI_API_KEY")
AZURE_API_VERSION = os.environ.get("AZURE_OPENAI_API_VERSION", "2025-03-01-preview")
AZURE_MODEL = os.environ.get("AZURE_OPENAI_DEPLOYMENT")

# Initialize Azure OpenAI client
client = AzureOpenAI(
    azure_endpoint=AZURE_ENDPOINT,
    api_key=AZURE_API_KEY,
    api_version=AZURE_API_VERSION,
)


@app.function_name(name="ResponseAPI")
@app.route(route="respond", methods=["GET", "POST"])
def respond(req: func.HttpRequest) -> func.HttpResponse:
    """
    Azure Function version of your local Responses API chatbot.
    Input: plain text
    Output: plain text
    """

    logging.info("Processing request using Azure OpenAI Responses API")

    # Get user input from GET or POST
    message = req.params.get("q")

    if not message:
        try:
            body = req.get_json()
            message = body.get("input")
        except:
            message = None

    if not message:
        return func.HttpResponse(
            "Send text with ?q=hello OR POST {\"input\": \"hello\"}",
            status_code=400,
        )

    try:
        # Call Azure OpenAI Responses API (same as your local code)
        response = client.responses.create(
            model=AZURE_MODEL,
            input=[{"role": "user", "content": message}],
        )

        # Extract reply like your local script
        try:
            reply = response.output[0].content[0].text
        except Exception:
            reply = str(response)

        return func.HttpResponse(
            reply,
            status_code=200,
            headers={"Content-Type": "text/plain"}
        )

    except Exception as e:
        logging.exception("Error calling Azure OpenAI Responses API")
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)
