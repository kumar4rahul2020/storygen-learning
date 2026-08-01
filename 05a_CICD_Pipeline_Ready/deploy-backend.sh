#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0;0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}🚀  StoryGen Backend Deployment Orchestrator        ${NC}"
echo -e "${BLUE}====================================================${NC}"

# --- 1. Load Parameters from terraform_code/input.tfvars if available ---
PROJECT_ID=""
REGION="us-central1"
BUCKET_NAME="storygen-workshop"
SECRET_NAME="sdlcv3-api-secret"
ENV="staging"

if [ -f "terraform_code/input.tfvars" ]; then
    echo -e "📖 Found ${GREEN}terraform_code/input.tfvars${NC}. Parsing variables..."
    PROJECT_ID=$(grep -E '^project_id[[:space:]]*=' terraform_code/input.tfvars | head -n 1 | cut -d'"' -f2)
    REGION=$(grep -E '^region[[:space:]]*=' terraform_code/input.tfvars | head -n 1 | cut -d'"' -f2)
    BUCKET_NAME=$(grep -E '^bucket_name[[:space:]]*=' terraform_code/input.tfvars | head -n 1 | cut -d'"' -f2)
    SECRET_NAME=$(grep -E '^secret_name[[:space:]]*=' terraform_code/input.tfvars | head -n 1 | cut -d'"' -f2)
else
    echo -e "⚠️  No ${YELLOW}terraform_code/input.tfvars${NC} found. Using defaults/env variables."
fi

# Fallback to active gcloud project if not explicitly set in tfvars
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
fi

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Error: Google Cloud project ID could not be detected.${NC}"
    echo "Please log in using 'gcloud auth login' and set your active project with:"
    echo "  gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "🎯 ${BLUE}Project ID:${NC}     ${GREEN}$PROJECT_ID${NC}"
echo -e "📍 ${BLUE}Region:${NC}         ${GREEN}$REGION${NC}"
echo -e "🪣  ${BLUE}Storage Bucket:${NC} ${GREEN}$BUCKET_NAME${NC}"
echo -e "🔑 ${BLUE}Secret Name:${NC}    ${GREEN}$SECRET_NAME${NC}"

# --- 2. Menu Selection ---
echo -e "\n${YELLOW}Please select deployment target environment:${NC}"
echo "1) Staging (Default, builds and deploys to staging)"
echo "2) Production (Builds and deploys to production)"
read -p "Select [1-2]: " env_choice

case $env_choice in
    2) ENV="production" ;;
    *) ENV="staging" ;;
esac

echo -e "\n${YELLOW}Select deployment method:${NC}"
echo "1) Automated Pipeline via Cloud Build (Recommended)"
echo "2) Direct Local Build & Deploy (Using local docker/gcloud)"
read -p "Select [1-2]: " method_choice

SERVICE_NAME="storygen-backend"
DEPLOYED_SERVICE_NAME="${SERVICE_NAME}-${ENV}"

# --- 3. Run Automated Tests ---
echo -e "\n🧪 Running local unit tests to verify code stability before build..."
if [ -d "../.venv" ]; then
    ../.venv/bin/pytest backend/test_main.py -v
else
    echo "⚠️  Virtual environment not detected at '../.venv'. Running with python3 -m pytest..."
    python3 -m pytest backend/test_main.py -v || { echo -e "${RED}❌ Tests failed. Aborting deployment!${NC}"; exit 1; }
fi
echo -e "${GREEN}✅ Local tests passed successfully!${NC}"

# --- 4. Deployment Logic ---
if [ "$method_choice" = "1" ]; then
    echo -e "\n⚡ ${BLUE}Submitting Cloud Build job to Google Cloud...${NC}"
    
    gcloud builds submit . \
        --config=backend/cloudbuild.yaml \
        --project="$PROJECT_ID" \
        --substitutions="_ENV=${ENV},_SERVICE_NAME=${SERVICE_NAME},_REGION=${REGION},_BUCKET_NAME=${BUCKET_NAME},_SECRET_NAME=${SECRET_NAME}"

else
    echo -e "\n🔨 ${BLUE}Performing Direct Local Build and Deploy...${NC}"
    
    # Enable necessary services
    echo "✅ Enabling required Cloud Run and Artifact Registry APIs..."
    gcloud services enable run.googleapis.com artifactregistry.googleapis.com --project="$PROJECT_ID"

    IMAGE_TAG="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:${ENV}"
    
    echo "🐳 Building Docker image locally..."
    docker build -t "$IMAGE_TAG" -f backend/Dockerfile backend/

    echo "⬆️  Pushing Docker image to GCR..."
    docker push "$IMAGE_TAG"

    echo "🚀 Deploying to Cloud Run..."
    gcloud run deploy "$DEPLOYED_SERVICE_NAME" \
        --image="$IMAGE_TAG" \
        --region="$REGION" \
        --platform="managed" \
        --allow-unauthenticated \
        --set-env-vars "GOOGLE_CLOUD_PROJECT_ID=${PROJECT_ID},GOOGLE_GENAI_USE_VERTEXAI=FALSE,GENMEDIA_BUCKET=${BUCKET_NAME}" \
        --set-secrets "GOOGLE_API_KEY=${SECRET_NAME}:latest" \
        --project="$PROJECT_ID"
fi

# --- 5. Output Results & Verification ---
SERVICE_URL=$(gcloud run services describe "$DEPLOYED_SERVICE_NAME" --platform="managed" --region="$REGION" --format="value(status.url)" --project="$PROJECT_ID" 2>/dev/null || echo "Unknown URL")

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}🎉  Backend Deployment Completed Successfully!     ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "🌐 ${BLUE}Service URL:${NC} ${GREEN}$SERVICE_URL${NC}"
echo -e "📋 ${BLUE}Environment:${NC} ${GREEN}$ENV${NC}"
echo -e "🛠️  ${BLUE}Rollback Instruction:${NC} To roll back to a previous revision, run:"
echo -e "   ${YELLOW}gcloud run services revisions list --service $DEPLOYED_SERVICE_NAME --region $REGION${NC}"
echo -e "   ${YELLOW}gcloud run services update-traffic $DEPLOYED_SERVICE_NAME --to-revisions=REVISION_NAME=100 --region $REGION${NC}"
echo -e "${GREEN}====================================================${NC}"
