import os
import psycopg2
from datetime import datetime, timedelta, timezone
import jwt
import requests
from uuid import uuid4
import time

# DB Info
POSTGRES_HOST: str = os.environ.get("POSTGRES_HOST")
POSTGRES_PORT: str = os.environ.get("POSTGRES_PORT")
POSTGRES_USER: str = os.environ.get("POSTGRES_USER")
POSTGRES_PASSWORD: str = os.environ.get("POSTGRES_PASSWORD")
POSTGRES_DB: str = os.environ.get("POSTGRES_DB")

# JWT Info
JWT_TOKEN_EXPIRY: int = 60 * 60 # 1 hour expiry
JWT_SECRET: str = os.environ.get("JWT_SECRET")
SERVICE_NAME: str = "unspecified"

# Service Info
BACKEND_SERVICE_URL: str = os.environ.get("BACKEND_URL")
BACKEND_SERVICE_NUM_REPLICAS: str = os.environ.get("BACKEND_NUM_REPLICAS")
PLATFORM_BACKEND_SERVICE_URL: str = os.environ.get("PLATFORM_BACKEND_URL")
PLATFORM_BACKEND_SERVICE_NUM_REPLICAS: str = os.environ.get("PLATFORM_BACKEND_NUM_REPLICAS")

X_SERVICE_KEY_HEADER = "X-Service-Key"

def test_langsmith_e2e_trace():

    print("INFO: Checking if backend services are ready...", flush=True)
    if not wait_for_backend_services_to_be_healthy():
        print("ERROR: Backend services are not ready, exiting", flush=True)
        exit(1)

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
        print("ERROR: No tenant or org id found in postgres")
        exit(1)

    cursor.close()
    conn.close()

    # Use tenant and org ids + JWT secret from environment to generate a JWT token. Then check if valid.
    jwt_token = generate_jwt_token(tenant_id, org_id)
    headers = {
        X_SERVICE_KEY_HEADER: jwt_token
    }
    if not validate_jwt_token(jwt_token, headers):
        print("ERROR: Failed to validate JWT token", flush=True)
        exit(1)

    try:
        # Create parent run - Chat Pipeline
        parent_run_id = uuid4()
        print(f"Parent run ID: {parent_run_id}", flush=True)
        post_run(
            parent_run_id, 
            "Chat Pipeline", 
            "chain", 
            {"question": "What is a LangSmith trace?"}, 
            headers
        )
        print(f"INFO: Created parent run", flush=True)
        
        # Create child run - LLM Call
        child_run_id = uuid4()
        print(f"Child run ID: {child_run_id}", flush=True)
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
        print(f"INFO: Created child run", flush=True)   

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
        print(f"INFO: Patched child run with LLM response", flush=True)

        # Patch parent run with final response
        patch_run(
            parent_run_id,
            {
                "answer": llm_response["generations"][0]["text"],
                "source_documents": []
            },
            headers
        )
        print(f"INFO: Patched parent run with final response", flush=True)

        parent_run = get_run(parent_run_id, headers)
        child_run = get_run(child_run_id, headers)


        if not validate_trace(parent_run, child_run, str(child_run_id)):
            print("ERROR: Failed to validate trace", flush=True)
            exit(1)

        if not validate_parent_run(parent_run, "What is a LangSmith trace?", llm_response["generations"][0]["text"], llm_response["llm_output"]["token_usage"]["total_tokens"]):
            print("ERROR: Failed to validate parent run", flush=True)
            exit(1)

        if not validate_child_run(child_run, "What is a LangSmith trace?", llm_response["generations"][0]["text"], llm_response["llm_output"]["token_usage"]["total_tokens"]):
            print("ERROR: Failed to validate child run", flush=True)
            exit(1)

        print("INFO: Test passed.", flush=True)
        exit(0)
    except Exception as e:
        print(f"ERROR: Error during run creation/patching/fetching: {str(e)}")
        exit(1)

def wait_for_backend_services_to_be_healthy(max_retries: int = 30, retry_delay: int = 10) -> bool:
    """
    Waits for both backend services to be healthy by checking their health endpoints.
    Ensures all replicas of each service are healthy before proceeding.
    """
    services = {
        "backend": {
            "url": f"{BACKEND_SERVICE_URL}/health",
            "replicas": int(BACKEND_SERVICE_NUM_REPLICAS or 1)
        },
        "platform-backend": {
            "url": f"{PLATFORM_BACKEND_SERVICE_URL}/health",
            "replicas": int(PLATFORM_BACKEND_SERVICE_NUM_REPLICAS or 3)
        }
    }

    attempt = 0
    while attempt < max_retries:
        all_replicas_healthy = True
        for service_name, service_info in services.items():
            healthy_replicas = 0
            for _ in range(service_info["replicas"]):
                try:
                    response = requests.get(service_info["url"], timeout=5)
                    if response.status_code == 200:
                        healthy_replicas += 1
                    else:
                        print(f"ERROR: {service_name} health check failed with status {response.status_code}", flush=True)
                except Exception as e:
                    print(f"ERROR: Failed to connect to {service_name}: {str(e)}", flush=True)

            if healthy_replicas == service_info["replicas"]:
                print(f"INFO: {service_name} has all {healthy_replicas}/{service_info['replicas']} replicas healthy", flush=True)
            else:
                print(f"WARN: {service_name} only has {healthy_replicas}/{service_info['replicas']} replicas healthy", flush=True)
                all_replicas_healthy = False
        
        if all_replicas_healthy:
            print("INFO: All backend services have all replicas healthy!", flush=True)
            return True
            
        attempt += 1
        if attempt < max_retries:
            print(f"Waiting for all replicas to be ready (attempt {attempt}/{max_retries}), retrying in {retry_delay} seconds...", flush=True)
            time.sleep(retry_delay)
    
    print(f"ERROR: Not all replicas ready after {max_retries} attempts ({max_retries * retry_delay} seconds)", flush=True)
    return False

def validate_parent_run(parent_run, question, answer, num_tokens) -> bool:
    if parent_run["inputs"]["question"] != question:
        print("ERROR: Parent run question does not match input question")
        return False
    if parent_run["outputs"]["answer"] != answer:
        print("ERROR: Parent run answer does not match output answer")
        return False
    if parent_run["total_tokens"] != num_tokens:
        print("ERROR: Parent run total tokens does not match input total tokens")
        return False
    return True

def validate_child_run(child_run, question, answer, num_tokens) -> bool:
    if child_run["inputs"]["messages"][0]["content"] != question:
        print("ERROR: Child run question does not match input question")
        return False
    if child_run["outputs"]["generations"][0]["text"] != answer:
        print("ERROR: Child run answer does not match output answer")
        return False
    if child_run["total_tokens"] != num_tokens:
        print("ERROR: Child run total tokens does not match input total tokens")
        return False
    return True

def validate_trace(parent_run, child_run, child_run_id) -> bool:
    """
    Validates the following:
    - Both runs have a trace id, and they are the same.
    - Child run is linked to the parent run and vice versa.
    """
    if parent_run["trace_id"] is None or parent_run["trace_id"] == "":
        print("ERROR: Parent run has no trace id")
        return False

    if child_run_id not in parent_run["child_run_ids"]:
        print("ERROR: Child run id not in parent run child run ids")
        return False

    if child_run["trace_id"] is None or child_run["trace_id"] == "":
        print("ERROR: Child run has no trace id")
        return False

    if child_run["trace_id"] != parent_run["trace_id"]:
        print("ERROR: Child run trace id does not match parent run trace id")
        return False

    if child_run["parent_run_id"] != parent_run["id"]:
        print("ERROR: Child run parent run id does not match parent run id")
        return False
    
    return True

def validate_jwt_token(jwt_token: str, headers: dict) -> bool:
    validate_url = f"{PLATFORM_BACKEND_SERVICE_URL}/internal/verify"
    response = requests.get(
        validate_url,
        headers=headers,
    )
    if response.status_code != 200:
        print(f"ERROR: Failed to validate JWT token: {response.status_code}", flush=True)
        return False
    return True

def generate_jwt_token(tenant_id: str, org_id: str) -> str:
    exp_datetime = datetime.now(tz=timezone.utc) + timedelta(
            seconds=JWT_TOKEN_EXPIRY
        )
    exp = int(exp_datetime.timestamp
              ())
    payload = {
        "sub": SERVICE_NAME,
        "exp": exp,
    }

    payload["tenant_id"] = tenant_id
    payload["organization_id"] = org_id
    payload["identity_permissions"] = ["runs:create"]
    token = jwt.encode(
        payload,
        JWT_SECRET,
        algorithm="HS256",
    )
    return token

def get_run(run_id, headers, max_retries=15, retry_delay=2):
    """
    Get a run with retries for 404s. Will retry for up to max_retries times with retry_delay seconds between attempts.
    """ 
    attempt = 0
    while attempt < max_retries:
        response = requests.get(
            f"{BACKEND_SERVICE_URL}/runs/{str(run_id)}",
            headers=headers
        )
        
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 404:
            attempt += 1
            if attempt < max_retries:
                print(f"WARN: Run not found (attempt {attempt}/{max_retries}), retrying in {retry_delay} seconds...", flush=True)
                time.sleep(retry_delay)
            continue
        else:
            raise Exception(f"ERROR: Failed to get run: {response.status_code} - {response.text}")
    
    raise Exception(f"ERROR: Run not found after {max_retries} attempts ({max_retries * retry_delay} seconds)")

def post_run(run_id, name, run_type, inputs, headers, parent_id=None):
    """Function to post a new run."""
    data = {
        "id": run_id.hex,
        "name": name,
        "run_type": run_type,
        "inputs": inputs,
        "start_time": datetime.now(timezone.utc).isoformat(),
    }
    if parent_id:
        data["parent_run_id"] = parent_id.hex
    
    response = requests.post(
        f"{PLATFORM_BACKEND_SERVICE_URL}/runs",
        json=data,
        headers=headers
    )
    
    if response.status_code != 202:
        print(f"ERROR: Failed to create run: {response.status_code} - {response.text}", flush=True)
        exit(1)
    
def patch_run(run_id, outputs, headers):
    """Function to patch an existing run."""
    response = requests.patch(
        f"{PLATFORM_BACKEND_SERVICE_URL}/runs/{run_id.hex}",
        json={
            "outputs": outputs,
            "end_time": datetime.now(timezone.utc).isoformat(),
        },
        headers=headers,
    )
    
    if response.status_code != 202:
        print(f"ERROR: Failed to patch run: {response.status_code} - {response.text}", flush=True)
        exit(1)
    
    print(f"INFO: Patched run: {response.json()}", flush=True)


if __name__ == "__main__":
    test_langsmith_e2e_trace()
