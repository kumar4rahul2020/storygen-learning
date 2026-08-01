#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔨 StoryGen Build - Docker Images${NC}"
echo "================================="

# Load environment variables
if [ -f "./load-env.sh" ]; then
    source ./load-env.sh
else
    echo -e "${RED}❌ load-env.sh not found. Cannot proceed without loading configuration.${NC}"
    exit 1
fi

# Generate timestamp for image versioning
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
VERSION_TAG="${TIMESTAMP}"

echo ""
echo -e "${BLUE}📋 Build Configuration:${NC}"
echo "   Project ID: $PROJECT_ID"
echo "   Region: $REGION"
echo "   Artifact Repo: $ARTIFACT_REPO"
echo "   Version Tag: $VERSION_TAG"
echo ""

# Build and push backend image
echo -e "${BLUE}🚀 Building Backend Image...${NC}"
echo "================================="

cd backend

BACKEND_IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${BACKEND_IMAGE_NAME}:${VERSION_TAG}"
BACKEND_IMAGE_URL_LATEST="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${BACKEND_IMAGE_NAME}:latest"

echo "🔨 Building: $BACKEND_IMAGE_URL"

gcloud builds submit \
    --tag "$BACKEND_IMAGE_URL" \
    --project="$PROJECT_ID"

# Also tag as latest
gcloud builds submit \
    --tag "$BACKEND_IMAGE_URL_LATEST" \
    --project="$PROJECT_ID"

echo -e "${GREEN}✅ Backend image built and pushed!${NC}"
echo "   Tagged: $BACKEND_IMAGE_URL"
echo "   Latest: $BACKEND_IMAGE_URL_LATEST"

cd ..

# Build and push frontend image
echo ""
echo -e "${BLUE}🚀 Building Frontend Image...${NC}"
echo "================================="

cd frontend

# Check if pnpm-lock.yaml exists and is up to date
if [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
    echo "🔍 Checking frontend dependencies..."
    if ! pnpm install --frozen-lockfile --dry-run &>/dev/null; then
        echo -e "${YELLOW}⚠️ pnpm-lock.yaml is outdated. Regenerating...${NC}"
        pnpm install --no-frozen-lockfile
        echo -e "${GREEN}✅ Dependencies updated${NC}"
    fi
fi

FRONTEND_IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${FRONTEND_IMAGE_NAME}:${VERSION_TAG}"
FRONTEND_IMAGE_URL_LATEST="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${FRONTEND_IMAGE_NAME}:latest"

echo "🔨 Building: $FRONTEND_IMAGE_URL"

# Build with placeholder backend URL (will be updated during infrastructure deployment)
PLACEHOLDER_BACKEND_URL="https://placeholder-backend.example.com"

gcloud builds submit \
    --project="$PROJECT_ID" \
    --config=cloudbuild.yaml \
    --substitutions="_BACKEND_URL=${PLACEHOLDER_BACKEND_URL},_IMAGE_NAME=${FRONTEND_IMAGE_URL}"

# Also tag as latest
gcloud builds submit \
    --project="$PROJECT_ID" \
    --config=cloudbuild.yaml \
    --substitutions="_BACKEND_URL=${PLACEHOLDER_BACKEND_URL},_IMAGE_NAME=${FRONTEND_IMAGE_URL_LATEST}"

echo -e "${GREEN}✅ Frontend image built and pushed!${NC}"
echo "   Tagged: $FRONTEND_IMAGE_URL"
echo "   Latest: $FRONTEND_IMAGE_URL_LATEST"

cd ..

# Save image URLs for Terraform
echo ""
echo -e "${BLUE}📝 Saving image references for Terraform...${NC}"

cat > terraform_code/images.tfvars << EOF
# Generated image references - $(date)
backend_image = "$BACKEND_IMAGE_URL_LATEST"
frontend_image = "$FRONTEND_IMAGE_URL_LATEST"
EOF

echo -e "${GREEN}✅ Images built and pushed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Image Summary:${NC}"
echo "   Backend:  $BACKEND_IMAGE_URL_LATEST"
echo "   Frontend: $FRONTEND_IMAGE_URL_LATEST"
echo ""
echo -e "${BLUE}🎯 Next step: Run ./03-deploy-infrastructure.sh${NC}"
