#!/bin/bash

# Get Secure Photo Downloader Authentication URL
# This script retrieves the Cognito Hosted UI URL for accessing the system

# Configuration
PROJECT_NAME="secure-photo-downloader"
AWS_REGION="us-east-1"  # CHANGE THIS TO MATCH YOUR DEPLOYMENT REGION
STACK_PREFIX="${PROJECT_NAME}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Secure Photo Downloader - Access Info          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if stack exists
stack_exists() {
    local stack_name="$1"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        &> /dev/null
}

# Get stack status
get_stack_status() {
    local stack_name="$1"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null
}

# Main function
main() {
    show_banner
    
    echo -e "${BLUE}🔍 Retrieving authentication information...${NC}"
    
    # Check AWS CLI and credentials
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed${NC}"
        echo "   Please install AWS CLI: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured${NC}"
        echo "   Run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    # Get AWS Account ID
    local aws_account_id
    aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    
    local auth_stack_name="${STACK_PREFIX}-auth"
    local compute_stack_name="${STACK_PREFIX}-compute"
    local storage_stack_name="${STACK_PREFIX}-storage"
    
    # Check if stacks exist
    echo -e "${BLUE}📊 Checking deployment status...${NC}"
    
    local stacks_status=()
    for stack in "$auth_stack_name" "$compute_stack_name" "$storage_stack_name"; do
        if stack_exists "$stack"; then
            local status=$(get_stack_status "$stack")
            stacks_status+=("$stack: $status")
            echo -e "   ✅ $stack: ${GREEN}$status${NC}"
        else
            stacks_status+=("$stack: NOT_FOUND")
            echo -e "   ❌ $stack: ${RED}NOT_FOUND${NC}"
        fi
    done
    
    # Check if auth stack exists
    if ! stack_exists "$auth_stack_name"; then
        echo -e "${RED}❌ Authentication stack '$auth_stack_name' not found${NC}"
        echo "   Make sure you have deployed the system first:"
        echo "   ./scripts/deploy.sh"
        exit 1
    fi
    
    # Get stack outputs
    echo -e "${BLUE}🔄 Retrieving configuration...${NC}"
    
    local hosted_ui_url
    local user_pool_id
    local client_id
    local domain
    local lambda_url
    local s3_bucket
    
    hosted_ui_url=$(aws cloudformation describe-stacks \
        --stack-name "$auth_stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`HostedUIURL`].OutputValue' \
        --output text 2>/dev/null)
    
    user_pool_id=$(aws cloudformation describe-stacks \
        --stack-name "$auth_stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
        --output text 2>/dev/null)
    
    client_id=$(aws cloudformation describe-stacks \
        --stack-name "$auth_stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
        --output text 2>/dev/null)
    
    domain=$(aws cloudformation describe-stacks \
        --stack-name "$auth_stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolDomain`].OutputValue' \
        --output text 2>/dev/null)
    
    # Get Lambda URL if compute stack exists
    if stack_exists "$compute_stack_name"; then
        lambda_url=$(aws cloudformation describe-stacks \
            --stack-name "$compute_stack_name" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionUrl`].OutputValue' \
            --output text 2>/dev/null)
    fi
    
    # Get S3 bucket if storage stack exists
    if stack_exists "$storage_stack_name"; then
        s3_bucket=$(aws cloudformation describe-stacks \
            --stack-name "$storage_stack_name" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
            --output text 2>/dev/null)
    fi
    
    # Display information
    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    ACCESS INFORMATION                        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "${GREEN}🌐 AUTHENTICATION URL:${NC}"
    echo -e "${CYAN}$hosted_ui_url${NC}"
    echo
    
    echo -e "${GREEN}📋 SYSTEM DETAILS:${NC}"
    echo -e "   Project: ${YELLOW}$PROJECT_NAME${NC}"
    echo -e "   AWS Account: ${YELLOW}$aws_account_id${NC}"
    echo -e "   Region: ${YELLOW}$AWS_REGION${NC}"
    echo -e "   User Pool ID: ${YELLOW}$user_pool_id${NC}"
    echo -e "   Client ID: ${YELLOW}$client_id${NC}"
    echo -e "   Domain: ${YELLOW}$domain${NC}"
    
    if [[ -n "$lambda_url" ]]; then
        echo -e "   Lambda URL: ${YELLOW}$lambda_url${NC}"
    fi
    
    if [[ -n "$s3_bucket" ]]; then
        echo -e "   S3 Bucket: ${YELLOW}$s3_bucket${NC}"
    fi
    
    echo
    echo -e "${GREEN}👤 ADMIN ACCOUNT:${NC}"
    echo -e "   Username: ${YELLOW}admin${NC}"
    echo -e "   Email: ${YELLOW}Check deployment output for admin email${NC}"
    echo -e "   Temp Password: ${YELLOW}SecureTemp123!$aws_account_id${NC}"
    echo -e "   ${RED}⚠️  Change password on first login!${NC}"
    
    echo
    echo -e "${GREEN}📱 QR CODE:${NC}"
    echo -e "   Generate a QR code for easy mobile access:"
    echo -e "   ${CYAN}https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$(echo "$hosted_ui_url" | sed 's/ /%20/g')${NC}"
    
    echo
    echo -e "${GREEN}📝 USAGE INSTRUCTIONS:${NC}"
    echo -e "   1. ${BLUE}Click the authentication URL above${NC}"
    echo -e "   2. ${BLUE}Sign in with your credentials${NC}"
    echo -e "   3. ${BLUE}Complete email verification if required${NC}"
    echo -e "   4. ${BLUE}You'll be redirected to the download page${NC}"
    echo -e "   5. ${BLUE}Your file download will start automatically${NC}"
    
    echo
    echo -e "${GREEN}🔒 SECURITY FEATURES:${NC}"
    echo -e "   • ${BLUE}Time-limited download links (1 hour expiry)${NC}"
    echo -e "   • ${BLUE}Private S3 storage with no public access${NC}"
    echo -e "   • ${BLUE}Authenticated access only${NC}"
    echo -e "   • ${BLUE}Encrypted storage and transmission${NC}"
    
    if [[ -n "$s3_bucket" ]]; then
        echo
        echo -e "${GREEN}📤 FILE UPLOAD:${NC}"
        echo -e "   To upload your photos:"
        echo -e "   ${CYAN}aws s3 cp your-photos.zip s3://$s3_bucket/photos/photos.zip${NC}"
        echo
        echo -e "   Or use the AWS Console:"
        echo -e "   ${CYAN}https://s3.console.aws.amazon.com/s3/buckets/$s3_bucket${NC}"
    fi
    
    echo
    echo -e "${GREEN}🔧 MONITORING:${NC}"
    echo -e "   CloudWatch Dashboard:"
    echo -e "   ${CYAN}https://$AWS_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$PROJECT_NAME-monitoring${NC}"
    
    echo
    echo -e "${YELLOW}💡 TIPS:${NC}"
    echo -e "   • Bookmark the authentication URL for easy access"
    echo -e "   • Share the URL with authorized users only"
    echo -e "   • Monitor usage through CloudWatch logs"
    echo -e "   • Download links expire automatically for security"
    
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    # Copy to clipboard if available
    if command -v pbcopy &> /dev/null; then
        echo "$hosted_ui_url" | pbcopy
        echo -e "${GREEN}✅ Authentication URL copied to clipboard (macOS)${NC}"
    elif command -v xclip &> /dev/null; then
        echo "$hosted_ui_url" | xclip -selection clipboard
        echo -e "${GREEN}✅ Authentication URL copied to clipboard (Linux)${NC}"
    elif command -v clip &> /dev/null; then
        echo "$hosted_ui_url" | clip
        echo -e "${GREEN}✅ Authentication URL copied to clipboard (Windows)${NC}"
    fi
    
    echo
    echo -e "${GREEN}🎉 Your Secure Photo Downloader is ready to use!${NC}"
}

# Error handling
trap 'echo -e "${RED}❌ Script failed at line $LINENO${NC}"; exit 1' ERR

# Run main function
main "$@"
