import os
import psycopg2
from datetime import datetime, timedelta, timezone
import jwt
import requests
from uuid import uuid4

# DB Info
POSTGRES_HOST: str = os.environ.get("POSTGRES_HOST")
POSTGRES_PORT: str = os.environ.get("POSTGRES_PORT")
POSTGRES_USER: str = os.environ.get("POSTGRES_USER")
POSTGRES_PASSWORD: str = os.environ.get("POSTGRES_PASSWORD")
POSTGRES_DB: str = os.environ.get("POSTGRES_DB")

# JWT Info
JWT_TOKEN_EXPIRY: int = 60 * 60 # 1 hour expiry
JWT_SECRET: str = os.environ.get("JWT_SECRET")
SERVICE_NAME: str = "langsmith-e2e-test"

# Service Info
BACKEND_SERVICE_URL: str = "http://langsmith-backend"
PLATFORM_BACKEND_SERVICE_URL: str = "http://langsmith-platform-backend"

def test_langsmith_e2e_trace():
    print(f"POSTGRES_HOST: {POSTGRES_HOST}")
    print(f"POSTGRES_PORT: {POSTGRES_PORT}")
    print(f"POSTGRES_USER: {POSTGRES_USER}")
    print(f"POSTGRES_PASSWORD: {POSTGRES_PASSWORD}")
    print(f"POSTGRES_DB: {POSTGRES_DB}")
    print(f"JWT_SECRET: {JWT_SECRET}")

    # Set up connection to posgtres DB. using environment variables from helm.
    conn = psycopg2.connect(
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        dbname=POSTGRES_DB
    )

    cursor = conn.cursor()

    cursor.execute("SELECT id, organization_id FROM tenants")
    tenant_id, org_id = cursor.fetchone()

    if not tenant_id or not org_id:
        print("No tenant or org id found in postgres")
        exit(1)

    cursor.close()
    conn.close()
    # Use tenant and org ids + JWT secret from environment to generate a JWT token.
    jwt_token = generate_jwt_token(tenant_id, org_id)
    print(f"JWT Token: {jwt_token}")
    # Verify the JWT token is valid.
    if not validate_jwt_token(jwt_token):
        print("Failed to validate JWT token")
        exit(1)
    
    headers = {
        "X-Service-Key": jwt_token
    }

    try:
        # Create parent run - Chat Pipeline
        parent_run_id = uuid4()
        post_run(
            parent_run_id, 
            "Chat Pipeline", 
            "chain", 
            {"question": "What is a LangSmith trace?"}, 
            headers
        )

        # Create child run - LLM Call
        child_run_id = uuid4()
        post_run(
            child_run_id, 
            "OpenAI Call", 
            "llm", 
            {
                "messages": [
                    {"role": "user", "content": "What is a LangSmith trace?"}
                ]
            }, 
            headers,
            parent_run_id
        )

        # Simulate LLM response
        llm_response = {
            "generations": [{
                "text": "A LangSmith trace is a detailed record of the execution of a LangChain application. It captures inputs, outputs, and metadata at each step of your language model pipeline, allowing you to monitor, debug, and optimize your application's performance. Traces show you the complete flow of data through your chains and agents, making it easier to understand how your application processes information and makes decisions.",
                "generation_info": {
                    "finish_reason": "stop",
                    "logprobs": None
                }
            }],
            "llm_output": {
                "token_usage": {
                    "prompt_tokens": 8,
                    "completion_tokens": 89,
                    "total_tokens": 97
                },
                "model_name": "gpt-3.5-turbo"
            }
        }

        # Patch child run with LLM response
        patch_run(
            child_run_id, 
            llm_response,
            headers
        )

        # Patch parent run with final response
        patch_run(
            parent_run_id,
            {
                "answer": llm_response["generations"][0]["text"],
                "source_documents": []
            },
            headers
        )

        print("Successfully created and patched runs")
        print("Test passed.")
        exit(0)
    except Exception as e:
        print(f"Error during run creation/patching: {str(e)}")
        exit(1)

def validate_jwt_token(jwt_token: str) -> bool:
    validate_url = f"{BACKEND_SERVICE_URL}/internal/verify"
    headers = {
        "X-Service-Key": jwt_token
    }
    response = requests.get(
        validate_url,
        headers=headers,
    )
    if response.status_code != 200:
        print(f"Failed to validate JWT token: {response.status_code}")
        return False
    return True

def generate_jwt_token(tenant_id: str, org_id: str) -> str:
    exp_datetime = datetime.now(tz=timezone.utc) + timedelta(
            seconds=JWT_TOKEN_EXPIRY
        )
    exp = int(exp_datetime.timestamp())
    payload = {
        "sub": SERVICE_NAME,
        "exp": exp,
         }

    payload["tenant_id"] = tenant_id
    payload["organization_id"] = org_id
    token = jwt.encode(
        payload,
        JWT_SECRET,
        algorithm="HS256",
    )
    return token

def post_run(run_id, name, run_type, inputs, headers, parent_id=None):
    """Function to post a new run to the API."""
    data = {
        "id": run_id.hex,
        "name": name,
        "run_type": run_type,
        "inputs": inputs,
        "start_time": datetime.utcnow().isoformat(),
    }
    if parent_id:
        data["parent_run_id"] = parent_id.hex
    
    response = requests.post(
        f"{BACKEND_SERVICE_URL}/runs",
        json=data,
        headers=headers
    )
    
    if response.status_code != 200:
        raise Exception(f"Failed to create run: {response.status_code} - {response.text}")
    
    print(f"Created run: {response.json()}")

def patch_run(run_id, outputs, headers):
    """Function to patch a run with outputs."""
    response = requests.patch(
        f"{BACKEND_SERVICE_URL}/runs/{run_id.hex}",
        json={
            "outputs": outputs,
            "end_time": datetime.now(timezone.utc).isoformat(),
        },
        headers=headers,
    )
    
    if response.status_code != 200:
        raise Exception(f"Failed to patch run: {response.status_code} - {response.text}")
    
    print(f"Patched run: {response.json()}")


if __name__ == "__main__":
    test_langsmith_e2e_trace()