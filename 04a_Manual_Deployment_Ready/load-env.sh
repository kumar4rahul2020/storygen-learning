#!/bin/bash

# Load environment variables from .env file
# Usage: source ./load-env.sh

ENV_FILE="../.env"

if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading environment variables from $ENV_FILE"
    
    # Load .env file, ignoring comments and empty lines
    export $(grep -E '^[a-zA-Z_]+\w*=' "$ENV_FILE")
    
    # Set derived variables for deployment
    export PROJECT_ID="$GOOGLE_CLOUD_PROJECT_ID"
    export REGION="${REGION:-us-central1}"
    export BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-genai-backend}"
    export FRONTEND_SERVICE_NAME="${FRONTEND_SERVICE_NAME:-genai-frontend}"
    export BACKEND_IMAGE_NAME="${BACKEND_IMAGE_NAME:-storygen-backend}"
    export FRONTEND_IMAGE_NAME="${FRONTEND_IMAGE_NAME:-storygen-frontend}"
    export ARTIFACT_REPO="${ARTIFACT_REPO:-storygen-repo}"
    export BUCKET_NAME="$GENMEDIA_BUCKET"
    export SECRET_NAME="${SECRET_MANAGER:-storygen-google-api-key}"
    export BACKEND_MEMORY="${BACKEND_MEMORY:-2Gi}"
    export BACKEND_CPU="${BACKEND_CPU:-2}"
    export FRONTEND_MEMORY="${FRONTEND_MEMORY:-1Gi}"
    export FRONTEND_CPU="${FRONTEND_CPU:-1}"
    export MIN_INSTANCES="${MIN_INSTANCES:-0}"
    export MAX_INSTANCES="${MAX_INSTANCES:-2}"
    
    echo "✅ Environment variables loaded successfully"
    echo "📋 Configuration Summary:"
    echo "   Project ID: $PROJECT_ID"
    echo "   Region: $REGION"
    echo "   Backend Service: $BACKEND_SERVICE_NAME"
    echo "   Frontend Service: $FRONTEND_SERVICE_NAME"
    echo "   Bucket: $BUCKET_NAME"
    echo "   Secret: $SECRET_NAME"
else
    echo "❌ Environment file not found: $ENV_FILE"
    echo "Please create a .env file in the parent directory with your configuration."
    echo "You can copy from env.template and customize for your project."
    exit 1
fi
