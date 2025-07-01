#!/bin/bash

# Secure Photo Downloader Deployment Script
# This script deploys the complete Secure Photo Downloader system to AWS

set -e  # Exit on any error

# Configuration - CUSTOMIZE THESE VALUES
PROJECT_NAME="secure-photo-downloader"
ADMIN_EMAIL="admin@example.com"      # CHANGE THIS TO YOUR EMAIL
AWS_REGION="us-east-1"               # CHANGE THIS TO YOUR PREFERRED REGION
ENVIRONMENT="production"             # Options: development, staging, production
STACK_PREFIX="${PROJECT_NAME}"

# Advanced Configuration (optional)
DOWNLOAD_EXPIRY_SECONDS=3600         # 1 hour default
LAMBDA_TIMEOUT=30                    # Lambda timeout in seconds
LAMBDA_MEMORY=256                    # Lambda memory in MB
LOG_RETENTION_DAYS=14                # CloudWatch logs retention

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

success() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 Secure Photo Downloader                      ║"
    echo "║              AWS Serverless Deployment Script               ║"
    echo "║                                                              ║"
    echo "║  🔐 Secure Authentication with AWS Cognito                   ║"
    echo "║  ☁️  Serverless Architecture with Lambda                     ║"
    echo "║  🗄️  Private S3 Storage with Time-Limited Access            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "cloudformation/auth-stack.yaml" ]]; then
        error "Please run this script from the project root directory"
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first: https://aws.amazon.com/cli/"
    fi
    
    # Check AWS CLI version
    AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    info "AWS CLI Version: $AWS_CLI_VERSION"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Run 'aws configure' first."
    fi
    
    # Get AWS Account ID and validate region
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CURRENT_REGION=$(aws configure get region)
    
    if [[ "$CURRENT_REGION" != "$AWS_REGION" ]]; then
        warn "Current AWS region ($CURRENT_REGION) differs from deployment region ($AWS_REGION)"
        warn "Using deployment region: $AWS_REGION"
    fi
    
    info "AWS Account ID: $AWS_ACCOUNT_ID"
    info "Deployment Region: $AWS_REGION"
    info "Environment: $ENVIRONMENT"
    
    # Validate email format
    if [[ ! "$ADMIN_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        error "Invalid email format: $ADMIN_EMAIL"
    fi
    
    # Check for existing stacks
    check_existing_stacks
    
    success "Prerequisites check passed ✓"
}

# Check for existing stacks
check_existing_stacks() {
    info "Checking for existing CloudFormation stacks..."
    
    local stacks=("${STACK_PREFIX}-compute" "${STACK_PREFIX}-storage" "${STACK_PREFIX}-auth")
    local existing_stacks=()
    
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$AWS_REGION" &> /dev/null; then
            existing_stacks+=("$stack")
        fi
    done
    
    if [[ ${#existing_stacks[@]} -gt 0 ]]; then
        warn "Found existing stacks: ${existing_stacks[*]}"
        echo -e "${YELLOW}Do you want to update existing stacks? (y/N): ${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "Deployment cancelled by user"
        fi
        UPDATE_STACKS=true
    else
        UPDATE_STACKS=false
    fi
}

# Deploy compute stack (Lambda)
deploy_compute_stack() {
    log "Deploying compute stack (Lambda function)..."
    
    local stack_name="${STACK_PREFIX}-compute"
    local bucket_name="${PROJECT_NAME}-${AWS_ACCOUNT_ID}-${AWS_REGION}-storage"
    
    local action="create-stack"
    if [[ "$UPDATE_STACKS" == "true" ]]; then
        action="update-stack"
    fi
    
    aws cloudformation $action \
        --stack-name "$stack_name" \
        --template-body file://cloudformation/compute-stack.yaml \
        --parameters \
            ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
            ParameterKey=S3BucketName,ParameterValue="$bucket_name" \
            ParameterKey=S3ObjectKey,ParameterValue="photos/photos.zip" \
            ParameterKey=DownloadExpirySeconds,ParameterValue="$DOWNLOAD_EXPIRY_SECONDS" \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            ParameterKey=LambdaTimeout,ParameterValue="$LAMBDA_TIMEOUT" \
            ParameterKey=LambdaMemorySize,ParameterValue="$LAMBDA_MEMORY" \
            ParameterKey=LogRetentionDays,ParameterValue="$LOG_RETENTION_DAYS" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --tags \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
            Key=ManagedBy,Value="CloudFormation" \
            Key=Purpose,Value="SecurePhotoDownloader"
    
    log "Waiting for compute stack deployment to complete..."
    aws cloudformation wait stack-${action//-stack/}-complete \
        --stack-name "$stack_name" \
        --region "$AWS_REGION"
    
    # Get Lambda Function URL
    LAMBDA_URL=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionUrl`].OutputValue' \
        --output text)
    
    success "Compute stack deployed successfully ✓"
    info "Lambda Function URL: $LAMBDA_URL"
}

# Deploy storage stack (S3)
deploy_storage_stack() {
    log "Deploying storage stack (S3 bucket)..."
    
    local stack_name="${STACK_PREFIX}-storage"
    local cognito_role_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-cognito-authenticated-role"
    
    local action="create-stack"
    if [[ "$UPDATE_STACKS" == "true" ]]; then
        action="update-stack"
    fi
    
    aws cloudformation $action \
        --stack-name "$stack_name" \
        --template-body file://cloudformation/storage-stack.yaml \
        --parameters \
            ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
            ParameterKey=CognitoRoleArn,ParameterValue="$cognito_role_arn" \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            ParameterKey=EnableVersioning,ParameterValue="true" \
            ParameterKey=LogRetentionDays,ParameterValue="$LOG_RETENTION_DAYS" \
        --region "$AWS_REGION" \
        --tags \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
            Key=ManagedBy,Value="CloudFormation" \
            Key=Purpose,Value="SecureStorage"
    
    log "Waiting for storage stack deployment to complete..."
    aws cloudformation wait stack-${action//-stack/}-complete \
        --stack-name "$stack_name" \
        --region "$AWS_REGION"
    
    # Get S3 bucket name
    S3_BUCKET_NAME=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
        --output text)
    
    success "Storage stack deployed successfully ✓"
    info "S3 Bucket: $S3_BUCKET_NAME"
}

# Deploy authentication stack (Cognito)
deploy_auth_stack() {
    log "Deploying authentication stack (Cognito)..."
    
    local stack_name="${STACK_PREFIX}-auth"
    
    local action="create-stack"
    if [[ "$UPDATE_STACKS" == "true" ]]; then
        action="update-stack"
    fi
    
    aws cloudformation $action \
        --stack-name "$stack_name" \
        --template-body file://cloudformation/auth-stack.yaml \
        --parameters \
            ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
            ParameterKey=CallbackURL,ParameterValue="$LAMBDA_URL" \
            ParameterKey=AdminEmail,ParameterValue="$ADMIN_EMAIL" \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --tags \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
            Key=ManagedBy,Value="CloudFormation" \
            Key=Purpose,Value="Authentication"
    
    log "Waiting for authentication stack deployment to complete..."
    aws cloudformation wait stack-${action//-stack/}-complete \
        --stack-name "$stack_name" \
        --region "$AWS_REGION"
    
    # Get Cognito Hosted UI URL
    HOSTED_UI_URL=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`HostedUIURL`].OutputValue' \
        --output text)
    
    success "Authentication stack deployed successfully ✓"
    info "Cognito Hosted UI URL: $HOSTED_UI_URL"
}

# Update Lambda function code
update_lambda_code() {
    log "Updating Lambda function with actual code..."
    
    local function_name="${PROJECT_NAME}-auth-handler"
    
    # Create deployment package
    local temp_dir=$(mktemp -d)
    cp lambda/auth-handler.py "$temp_dir/"
    cp lambda/requirements.txt "$temp_dir/"
    
    cd "$temp_dir"
    
    # Install dependencies if requirements.txt has content
    if [[ -s requirements.txt ]]; then
        pip install -r requirements.txt -t .
    fi
    
    # Create zip file
    zip -r function.zip .
    
    # Update Lambda function
    aws lambda update-function-code \
        --function-name "$function_name" \
        --zip-file fileb://function.zip \
        --region "$AWS_REGION"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    success "Lambda function code updated ✓"
}

# Create sample photos directory
create_sample_structure() {
    log "Creating sample file structure..."
    
    local sample_dir="sample-photos"
    mkdir -p "$sample_dir"
    
    # Create a sample README file
    cat > "$sample_dir/README.txt" << EOF
Secure Photo Downloader - Sample Files

This directory contains sample files for your secure photo downloader.

To upload your photos:
1. Place your photos in this directory
2. Create a zip file: zip -r photos.zip *
3. Upload to S3: aws s3 cp photos.zip s3://$S3_BUCKET_NAME/photos/photos.zip

Your photos will then be available for secure download through the authentication system.

Bucket: $S3_BUCKET_NAME
Region: $AWS_REGION
Authentication URL: $HOSTED_UI_URL
EOF
    
    success "Sample structure created in $sample_dir/ ✓"
}

# Display deployment summary
show_deployment_summary() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    DEPLOYMENT SUCCESSFUL!                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎉 Your Secure Photo Downloader has been deployed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Summary:${NC}"
    echo -e "   Project Name: ${YELLOW}$PROJECT_NAME${NC}"
    echo -e "   Environment: ${YELLOW}$ENVIRONMENT${NC}"
    echo -e "   AWS Region: ${YELLOW}$AWS_REGION${NC}"
    echo -e "   AWS Account: ${YELLOW}$AWS_ACCOUNT_ID${NC}"
    echo ""
    echo -e "${BLUE}🔗 Important URLs:${NC}"
    echo -e "   Authentication URL: ${CYAN}$HOSTED_UI_URL${NC}"
    echo -e "   Lambda Function URL: ${CYAN}$LAMBDA_URL${NC}"
    echo ""
    echo -e "${BLUE}🗄️ Storage Information:${NC}"
    echo -e "   S3 Bucket: ${YELLOW}$S3_BUCKET_NAME${NC}"
    echo -e "   File Path: ${YELLOW}photos/photos.zip${NC}"
    echo ""
    echo -e "${BLUE}👤 Admin Account:${NC}"
    echo -e "   Email: ${YELLOW}$ADMIN_EMAIL${NC}"
    echo -e "   Temporary Password: ${YELLOW}SecureTemp123!$AWS_ACCOUNT_ID${NC}"
    echo -e "   ${RED}⚠️  Change password on first login!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo -e "   1. Upload your photos to: ${YELLOW}s3://$S3_BUCKET_NAME/photos/photos.zip${NC}"
    echo -e "   2. Visit the authentication URL to test the system"
    echo -e "   3. Check the sample-photos/ directory for upload instructions"
    echo -e "   4. Monitor your deployment in CloudWatch"
    echo ""
    echo -e "${GREEN}🔒 Your photos are now securely protected with time-limited access!${NC}"
}

# Main deployment function
main() {
    show_banner
    
    log "Starting Secure Photo Downloader deployment..."
    
    check_prerequisites
    deploy_compute_stack
    deploy_storage_stack
    deploy_auth_stack
    update_lambda_code
    create_sample_structure
    
    show_deployment_summary
    
    success "Deployment completed successfully! 🎉"
}

# Error handling
trap 'error "Deployment failed at line $LINENO"' ERR

# Run main function
main "$@"
