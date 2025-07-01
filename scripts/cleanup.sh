#!/bin/bash

# Secure Photo Downloader Cleanup Script
# This script removes all AWS resources created by the deployment

set -e  # Exit on any error

# Configuration
PROJECT_NAME="secure-photo-downloader"
AWS_REGION="us-east-1"  # CHANGE THIS TO MATCH YOUR DEPLOYMENT REGION
STACK_PREFIX="${PROJECT_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
show_banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  CLEANUP WARNING ⚠️                     ║"
    echo "║              Secure Photo Downloader Removal                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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

# Get S3 bucket name from stack
get_s3_bucket_name() {
    local stack_name="${STACK_PREFIX}-storage"
    if stack_exists "$stack_name"; then
        aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
            --output text 2>/dev/null
    fi
}

# Confirmation prompt
confirm_cleanup() {
    show_banner
    
    echo -e "${RED}⚠️  DANGER: This will permanently delete ALL resources!${NC}"
    echo
    echo -e "${YELLOW}Resources to be deleted:${NC}"
    echo "• 🗄️  S3 bucket and all stored files"
    echo "• ⚡ Lambda function and execution logs"
    echo "• 🔐 Cognito User Pool and all user accounts"
    echo "• 🔑 IAM roles and security policies"
    echo "• 📊 CloudWatch logs and metrics"
    echo "• 📈 CloudWatch dashboard"
    echo "• 💀 Dead letter queue"
    echo
    
    # Check what actually exists
    local existing_stacks=()
    local stacks=("${STACK_PREFIX}-auth" "${STACK_PREFIX}-compute" "${STACK_PREFIX}-storage")
    
    echo -e "${BLUE}📊 Current deployment status:${NC}"
    for stack in "${stacks[@]}"; do
        if stack_exists "$stack"; then
            local status=$(get_stack_status "$stack")
            existing_stacks+=("$stack")
            echo -e "   ✅ $stack: ${GREEN}$status${NC}"
        else
            echo -e "   ❌ $stack: ${RED}NOT_FOUND${NC}"
        fi
    done
    
    if [[ ${#existing_stacks[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No stacks found to delete.${NC}"
        exit 0
    fi
    
    # Get S3 bucket info
    local s3_bucket=$(get_s3_bucket_name)
    if [[ -n "$s3_bucket" ]]; then
        echo
        echo -e "${BLUE}📦 S3 Bucket Information:${NC}"
        echo -e "   Bucket: ${YELLOW}$s3_bucket${NC}"
        
        # Check if bucket has objects
        local object_count
        object_count=$(aws s3api list-objects-v2 --bucket "$s3_bucket" --query 'KeyCount' --output text 2>/dev/null || echo "0")
        if [[ "$object_count" -gt 0 ]]; then
            echo -e "   Objects: ${RED}$object_count files will be permanently deleted${NC}"
        else
            echo -e "   Objects: ${GREEN}Empty bucket${NC}"
        fi
    fi
    
    echo
    echo -e "${RED}⚠️  THIS ACTION CANNOT BE UNDONE! ⚠️${NC}"
    echo
    echo -e "${YELLOW}Type 'DELETE' (in capitals) to confirm permanent deletion:${NC}"
    read -r confirmation
    
    if [[ "$confirmation" != "DELETE" ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi
    
    echo
    echo -e "${YELLOW}Final confirmation - type 'yes' to proceed:${NC}"
    read -r final_confirmation
    
    if [[ "$final_confirmation" != "yes" ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi
}

# Empty and prepare S3 bucket for deletion
cleanup_s3_bucket() {
    local bucket_name=$(get_s3_bucket_name)
    
    if [[ -z "$bucket_name" ]]; then
        info "No S3 bucket found to clean up"
        return
    fi
    
    log "Cleaning up S3 bucket: $bucket_name"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        warn "S3 bucket $bucket_name does not exist or is not accessible"
        return
    fi
    
    # Delete all objects and versions
    info "Deleting all objects from S3 bucket..."
    aws s3 rm "s3://$bucket_name" --recursive || warn "Failed to delete some objects"
    
    # Delete all object versions (if versioning is enabled)
    info "Deleting all object versions..."
    aws s3api list-object-versions --bucket "$bucket_name" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | \
    while read -r key version_id; do
        if [[ -n "$key" && -n "$version_id" ]]; then
            aws s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" || true
        fi
    done
    
    # Delete all delete markers
    info "Deleting all delete markers..."
    aws s3api list-object-versions --bucket "$bucket_name" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | \
    while read -r key version_id; do
        if [[ -n "$key" && -n "$version_id" ]]; then
            aws s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" || true
        fi
    done
    
    success "S3 bucket cleaned up successfully"
}

# Delete CloudFormation stack
delete_stack() {
    local stack_name="$1"
    local stack_type="$2"
    
    if ! stack_exists "$stack_name"; then
        info "$stack_type stack '$stack_name' does not exist"
        return
    fi
    
    log "Deleting $stack_type stack: $stack_name"
    
    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        --region "$AWS_REGION"
    
    log "Waiting for $stack_type stack deletion to complete..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" || {
        warn "$stack_type stack deletion may have failed or timed out"
        return 1
    }
    
    success "$stack_type stack deleted successfully"
}

# Clean up CloudWatch logs that might not be deleted with stacks
cleanup_cloudwatch_logs() {
    log "Cleaning up CloudWatch log groups..."
    
    local log_groups=(
        "/aws/lambda/${PROJECT_NAME}-auth-handler"
        "/aws/s3/${PROJECT_NAME}-access-logs"
        "/aws/cognito/${PROJECT_NAME}"
    )
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$AWS_REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
            info "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region "$AWS_REGION" || warn "Failed to delete log group: $log_group"
        fi
    done
    
    success "CloudWatch logs cleanup completed"
}

# Main cleanup function
main() {
    log "Starting Secure Photo Downloader cleanup..."
    
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured"
    fi
    
    # Get confirmation
    confirm_cleanup
    
    log "Beginning resource cleanup..."
    
    # Clean up S3 bucket first (must be empty before stack deletion)
    cleanup_s3_bucket
    
    # Delete stacks in reverse dependency order
    local stacks_to_delete=(
        "${STACK_PREFIX}-auth:Authentication"
        "${STACK_PREFIX}-compute:Compute"
        "${STACK_PREFIX}-storage:Storage"
    )
    
    for stack_info in "${stacks_to_delete[@]}"; do
        IFS=':' read -r stack_name stack_type <<< "$stack_info"
        delete_stack "$stack_name" "$stack_type"
    done
    
    # Clean up any remaining CloudWatch logs
    cleanup_cloudwatch_logs
    
    # Clean up local sample directory if it exists
    if [[ -d "sample-photos" ]]; then
        log "Removing local sample-photos directory..."
        rm -rf sample-photos
        success "Local sample directory removed"
    fi
    
    show_cleanup_summary
}

# Display cleanup summary
show_cleanup_summary() {
    echo
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    CLEANUP COMPLETED!                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${GREEN}🎉 All Secure Photo Downloader resources have been removed!${NC}"
    echo
    echo -e "${BLUE}📋 Cleanup Summary:${NC}"
    echo -e "   Project: ${YELLOW}$PROJECT_NAME${NC}"
    echo -e "   Region: ${YELLOW}$AWS_REGION${NC}"
    echo -e "   Timestamp: ${YELLOW}$(date)${NC}"
    echo
    echo -e "${BLUE}✅ Resources Removed:${NC}"
    echo -e "   • Authentication stack (Cognito User Pool)"
    echo -e "   • Compute stack (Lambda function)"
    echo -e "   • Storage stack (S3 bucket and policies)"
    echo -e "   • CloudWatch logs and metrics"
    echo -e "   • IAM roles and policies"
    echo -e "   • Local sample directories"
    echo
    echo -e "${BLUE}💰 Cost Impact:${NC}"
    echo -e "   • No more charges for Lambda executions"
    echo -e "   • No more charges for S3 storage"
    echo -e "   • No more charges for Cognito active users"
    echo -e "   • CloudWatch logs charges stopped"
    echo
    echo -e "${YELLOW}📝 Next Steps:${NC}"
    echo -e "   • Verify no unexpected charges in AWS billing"
    echo -e "   • Check for any remaining resources in AWS Console"
    echo -e "   • Remove any bookmarked authentication URLs"
    echo -e "   • Update any documentation referencing this deployment"
    echo
    echo -e "${GREEN}🔒 Your AWS account is now clean of Secure Photo Downloader resources!${NC}"
}

# Error handling
trap 'error "Cleanup failed at line $LINENO"' ERR

# Run main function
main "$@"
