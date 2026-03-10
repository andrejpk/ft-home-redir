# FT Home Redirect Service

A lightweight nginx-based redirect service for Friday Threads, designed to run on Azure App Service for Linux.

## What it does

This service handles HTTP redirects for the Friday Threads domain:

- `/` → `https://shop.fridaythreads.com`
- `/store/[path]` → `https://store.fridaythreads.com/[path]`
- All other paths → `https://shop.fridaythreads.com` (fallback)

## Architecture

- **Base Image**: nginx:alpine (minimal, secure, efficient)
- **Platform**: Azure App Service for Linux
- **CI/CD**: GitHub Actions
- **Health Check**: `/health` endpoint for Azure monitoring

## Setup Instructions

### Prerequisites

1. Azure Container Registry (ACR)
2. Azure App Service for Linux
3. GitHub repository with Actions enabled

### Azure Setup

#### 1. Create Azure Container Registry

```bash
# Set variables
RESOURCE_GROUP="rg-fridaythreads"
ACR_NAME="fthreadsacr"  # Must be globally unique, lowercase alphanumeric
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create container registry
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

# Get ACR credentials
az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP
```

#### 2. Create Azure App Service

```bash
# Create App Service Plan (Linux)
az appservice plan create \
  --name ft-home-redir-plan \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --sku B1

# Create Web App
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan ft-home-redir-plan \
  --name ft-home-redir \
  --deployment-container-image-name $ACR_NAME.azurecr.io/ft-home-redir:latest

# Configure ACR credentials for the Web App
az webapp config container set \
  --name ft-home-redir \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name $ACR_NAME.azurecr.io/ft-home-redir:latest \
  --docker-registry-server-url https://$ACR_NAME.azurecr.io \
  --docker-registry-server-user <username-from-step-1> \
  --docker-registry-server-password <password-from-step-1>

# Get publish profile
az webapp deployment list-publishing-profiles \
  --name ft-home-redir \
  --resource-group $RESOURCE_GROUP \
  --xml > publish-profile.xml
```

### GitHub Setup

#### Required Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add:

1. **ACR_LOGIN_SERVER**: Your ACR login server (e.g., `fthreadsacr.azurecr.io`)
2. **ACR_USERNAME**: ACR admin username (from step 1)
3. **ACR_PASSWORD**: ACR admin password (from step 1)
4. **AZURE_WEBAPP_PUBLISH_PROFILE**: Contents of the `publish-profile.xml` file

#### Update Workflow

Edit `.github/workflows/azure-deploy.yml` and change:

```yaml
env:
  AZURE_WEBAPP_NAME: ft-home-redir  # Your Azure App Service name
```

### Deployment

Once configured, every push to the `main` branch will automatically:

1. Build the Docker image
2. Push it to Azure Container Registry
3. Deploy to Azure App Service

You can also manually trigger deployment from the GitHub Actions tab.

## Local Development

### Build and run locally

```bash
# Build the image
docker build -t ft-home-redir:local .

# Run locally
docker run -p 8080:80 ft-home-redir:local

# Test redirects
curl -I http://localhost:8080/
curl -I http://localhost:8080/store/products
curl http://localhost:8080/health
```

### Test nginx configuration

```bash
# Test nginx config syntax
docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/conf.d/default.conf nginx:alpine nginx -t
```

## Monitoring

The service includes a `/health` endpoint that returns 200 OK when healthy. Azure App Service will use this for health checks.

View logs in Azure:

```bash
az webapp log tail --name ft-home-redir --resource-group $RESOURCE_GROUP
```

## Troubleshooting

### Container fails to start

```bash
# Check container logs
az webapp log tail --name ft-home-redir --resource-group $RESOURCE_GROUP

# Check deployment logs
az webapp log deployment show --name ft-home-redir --resource-group $RESOURCE_GROUP
```

### ACR authentication issues

```bash
# Verify ACR credentials
az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP

# Test ACR login
docker login $ACR_NAME.azurecr.io
```

### Redirects not working

1. Check nginx logs in Azure portal
2. Verify the app is accessible
3. Test with curl to see actual redirect responses

## Security Notes

- The container runs nginx as a non-root user
- Only port 80 is exposed (Azure handles HTTPS termination)
- Admin credentials for ACR should be rotated regularly
- Consider using Managed Identity instead of admin credentials for production

## Cost Optimization

- **App Service Plan**: B1 tier (~$13/month)
- **Container Registry**: Basic tier (~$5/month)
- Total: ~$18/month

For production, consider:
- Standard tier for auto-scaling
- Premium ACR for geo-replication
- Application Insights for monitoring

## License

MIT
