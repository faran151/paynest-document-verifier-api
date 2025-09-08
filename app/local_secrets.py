MOCK_SECRETS = {
    "api_key": "local-development-api-key"
}

def get_local_secret(secret_name):
    """Mock implementation of get_secret for local development"""
    return MOCK_SECRETS