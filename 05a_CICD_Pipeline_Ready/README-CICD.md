# StoryGen CI/CD Pipeline Setup Guide

This guide explains how to set up and use the automated CI/CD pipeline for the StoryGen Backend.

## Architecture Overview

The CI/CD pipeline uses **GitHub Actions** as the central orchestrator and **Google Cloud Build** for building, testing, and deploying the containerized FastAPI backend to **Google Cloud Run**.

```
                           +----------------------+
                           |   GitHub Repository  |
                           +----------+-----------+
                                      |
                           Push / PR  v (GitHub Actions)
                           +----------+-----------+
                           |  1. Run Pytest       |
                           |  2. Authenticate GCP |
                           +----------+-----------+
                                      |
                     Trigger Build    v (gcloud builds submit)
                           +----------+-----------+
                           |  Google Cloud Build  |
                           +----------+-----------+
                                      |
             +------------------------+------------------------+
             |                                                 |
             v (Main Branch Push)                              v (Git Release / Tag v*)
+------------+------------+                       +------------+------------+
| Deploy Staging Cloud Run|                       |  Deploy Prod Cloud Run  |
|  genai-backend-staging  |                       | genai-backend-production|
+-------------------------+                       +-------------------------+
```

---

## Prerequisites & Setup

To make the pipeline fully autonomous, you need to configure authentication between GitHub and Google Cloud.

### Step 1: Configure Google Cloud IAM
The pipeline needs permissions to build Docker images and deploy to Cloud Run. Create a dedicated Google Cloud Service Account or use your existing one:

1. **Enable required Google Cloud APIs:**
   ```bash
   gcloud services enable iam.googleapis.com \
                          run.googleapis.com \
                          cloudbuild.googleapis.com \
                          artifactregistry.googleapis.com \
                          secretmanager.googleapis.com
   ```

2. **Assign the following roles to the Service Account:**
   - `roles/cloudbuild.builds.editor` (To submit and run Cloud Build jobs)
   - `roles/run.admin` (To deploy to Cloud Run)
   - `roles/iam.serviceAccountUser` (To run Cloud Run as the service account)
   - `roles/viewer` (To view project configuration)

3. **Generate a Service Account JSON Key:**
   ```bash
   gcloud iam service-accounts keys create sa-key.json \
       --iam-account=YOUR_SERVICE_ACCOUNT_EMAIL
   ```

### Step 2: Configure GitHub Secrets
Go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions** and add the following repository secrets:

| Secret Name | Description | Required |
| :--- | :--- | :--- |
| `GCP_SA_KEY` | The full contents of your `sa-key.json` file. | Yes (If not using WIF) |
| `GCP_PROJECT_ID` | Your Google Cloud Project ID (e.g., `sdlcv3`). | Yes (Fallback if not in tfvars) |
| `GCP_SA_EMAIL` | The email address of your GCP Service Account. | Optional (For WIF) |
| `GCP_WIF_PROVIDER` | Workload Identity Provider ID (for passwordless auth). | Optional (Alternative to JSON key)|
| `SLACK_WEBHOOK_URL`| Slack Incoming Webhook URL for build notifications. | Optional |

---

## How to Trigger Deployments

### 1. Staging Deployments
Pushing or merging code into the `main` branch automatically triggers the pipeline:
1. GitHub Actions runs unit tests (`pytest`).
2. GitHub Actions triggers Google Cloud Build.
3. Cloud Build builds the Docker image and deploys it to `genai-backend-staging` on Google Cloud Run.

### 2. Production Deployments
To push a stable release to production, use Git tags:
1. Create a tag matching the `v*` pattern (e.g., `v1.0.0`):
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. The pipeline will automatically run the full suite of tests, build, and deploy the immutable version to `genai-backend-production` on Google Cloud Run.

### 3. Pull Request Validation
Opening a Pull Request targeting `main` triggers a lightweight **test job** in GitHub Actions. It runs the full unit test suite using `pytest` but does not deploy. This ensures PRs are safe and verified before they are merged.

---

## Manual/Local Deployment Script

If you need to deploy directly from your local terminal or trigger Cloud Build manually, use the included `deploy-backend.sh` script:

```bash
./deploy-backend.sh
```

This script will:
1. Dynamically read project parameters from `terraform_code/input.tfvars` if available.
2. Run your local backend unit tests.
3. Offer an interactive prompt to choose between **Staging** and **Production**.
4. Offer to deploy using **Cloud Build** or **Direct local build**.
5. Log service details and instructions for rollbacks on complete success.
