# Deployment Guide - Secure Photo Downloader

This comprehensive guide will walk you through deploying the Secure Photo Downloader system to AWS.

## 📋 Prerequisites

### Required Tools
- **AWS CLI v2.0+**: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Git**: For cloning the repository
- **Bash**: For running deployment scripts (Linux/macOS/WSL)

### AWS Requirements
- **AWS Account** with appropriate permissions
- **AWS CLI configured** with valid credentials
- **Permissions** for the following services:
  - CloudFormation (full access)
  - IAM (create/manage roles and policies)
  - Lambda (create/manage functions)
  - S3 (create/manage buckets)
  - Cognito (create/manage user pools)
  - CloudWatch (create/manage logs and metrics)

### Minimum IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "iam:*",
                "lambda:*",
                "s3:*",
                "cognito-idp:*",
                "cognito-identity:*",
                "logs:*",
                "sqs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🚀 Quick Deployment

### Step 1: Clone and Configure
```bash
# Clone the repository
git clone <your-repo-url>
cd secure-photo-downloader

# Make scripts executable
chmod +x scripts/*.sh

# Edit configuration in scripts/deploy.sh
nano scripts/deploy.sh
```

### Step 2: Configure Deployment Settings
Edit the following variables in `scripts/deploy.sh`:

```bash
# Required Configuration
PROJECT_NAME="secure-photo-downloader"    # Your project name
ADMIN_EMAIL="your-email@example.com"      # Your admin email
AWS_REGION="us-east-1"                    # Your preferred region
ENVIRONMENT="production"                   # Environment type

# Optional Advanced Configuration
DOWNLOAD_EXPIRY_SECONDS=3600              # Link expiry (1 hour)
LAMBDA_TIMEOUT=30                         # Lambda timeout
LAMBDA_MEMORY=256                         # Lambda memory (MB)
LOG_RETENTION_DAYS=14                     # Log retention period
```

### Step 3: Deploy
```bash
# Run the deployment script
./scripts/deploy.sh
```

The deployment process will:
1. ✅ Check prerequisites and AWS credentials
2. ✅ Deploy compute stack (Lambda function)
3. ✅ Deploy storage stack (S3 bucket with security)
4. ✅ Deploy authentication stack (Cognito)
5. ✅ Update Lambda function with actual code
6. ✅ Create sample file structure
7. ✅ Display access information

## 📁 Detailed Deployment Steps

### Phase 1: Compute Stack (Lambda)
Creates:
- Lambda execution role with S3 permissions
- Lambda function for authentication handling
- Function URL for public access
- CloudWatch log group
- Dead letter queue for error handling
- CloudWatch dashboard for monitoring

### Phase 2: Storage Stack (S3)
Creates:
- Private S3 bucket with encryption
- Bucket policy restricting access to authenticated users
- Lifecycle policies for cost optimization
- CloudWatch logging for access monitoring
- Metric filters for security monitoring

### Phase 3: Authentication Stack (Cognito)
Creates:
- Cognito User Pool with security policies
- User Pool Client with OAuth configuration
- Identity Pool for AWS credentials
- IAM roles for authenticated users
- Admin user account
- Hosted UI domain

### Phase 4: Integration
- Updates Lambda function with production code
- Configures environment variables
- Tests integration between components
- Creates sample file structure

## 🔧 Configuration Options

### Environment Variables
The Lambda function uses these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `BUCKET_NAME` | Auto-generated | S3 bucket name |
| `OBJECT_KEY` | `photos/photos.zip` | File path in S3 |
| `DOWNLOAD_EXPIRY` | `3600` | Link expiry (seconds) |
| `APP_NAME` | `Secure Photo Downloader` | Application name |
| `ENVIRONMENT` | `production` | Environment type |
| `LOG_LEVEL` | `INFO` | Logging level |

### Customization Options

#### 1. Change Download Expiry Time
```bash
# In scripts/deploy.sh
DOWNLOAD_EXPIRY_SECONDS=7200  # 2 hours
```

#### 2. Modify Lambda Resources
```bash
# In scripts/deploy.sh
LAMBDA_TIMEOUT=60      # 1 minute timeout
LAMBDA_MEMORY=512      # 512 MB memory
```

#### 3. Adjust Log Retention
```bash
# In scripts/deploy.sh
LOG_RETENTION_DAYS=30  # 30 days retention
```

#### 4. Change File Location
Edit the CloudFormation parameter in `scripts/deploy.sh`:
```bash
ParameterKey=S3ObjectKey,ParameterValue="files/download.zip"
```

## 📤 File Upload

### Method 1: AWS CLI
```bash
# Get bucket name from deployment output
BUCKET_NAME="your-bucket-name"

# Upload single file
aws s3 cp your-photos.zip s3://$BUCKET_NAME/photos/photos.zip

# Upload directory as zip
zip -r photos.zip /path/to/photos/
aws s3 cp photos.zip s3://$BUCKET_NAME/photos/photos.zip
```

### Method 2: AWS Console
1. Navigate to [S3 Console](https://console.aws.amazon.com/s3/)
2. Find your bucket (format: `secure-photo-downloader-ACCOUNT-REGION-storage`)
3. Create `photos/` folder if it doesn't exist
4. Upload your `photos.zip` file

### Method 3: Programmatic Upload
```python
import boto3

s3 = boto3.client('s3')
bucket_name = 'your-bucket-name'

# Upload file
s3.upload_file('local-photos.zip', bucket_name, 'photos/photos.zip')
```

## 🔍 Verification and Testing

### 1. Check Deployment Status
```bash
# Get authentication URL
./scripts/get-auth-url.sh

# Check CloudFormation stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
```

### 2. Test Authentication Flow
1. Visit the Hosted UI URL from deployment output
2. Sign up with a new account or use admin credentials
3. Complete email verification
4. Verify redirect to download page
5. Confirm file download starts automatically

### 3. Monitor Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/secure-photo-downloader-auth-handler --follow

# View S3 access logs
aws logs tail /aws/s3/secure-photo-downloader-access-logs --follow
```

## 🔒 Security Considerations

### 1. Admin Account Security
- Change the temporary password immediately
- Enable MFA if required
- Use strong, unique passwords

### 2. S3 Bucket Security
- Bucket is private by default
- All access requires authentication
- Objects are encrypted at rest
- Access logging is enabled

### 3. Lambda Security
- Function has minimal required permissions
- Environment variables are encrypted
- Dead letter queue captures failed invocations
- CloudWatch monitoring enabled

### 4. Cognito Security
- Strong password policy enforced
- Email verification required
- OAuth flows properly configured
- Token expiration configured

## 📊 Monitoring and Maintenance

### CloudWatch Dashboards
Access your monitoring dashboard:
```
https://REGION.console.aws.amazon.com/cloudwatch/home?region=REGION#dashboards:name=secure-photo-downloader-monitoring
```

### Key Metrics to Monitor
- Lambda invocations and errors
- S3 access patterns
- Cognito authentication attempts
- Download success rates

### Log Analysis
```bash
# Search for errors in Lambda logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/secure-photo-downloader-auth-handler \
  --filter-pattern "ERROR"

# Monitor S3 access patterns
aws logs filter-log-events \
  --log-group-name /aws/s3/secure-photo-downloader-access-logs \
  --filter-pattern "GET"
```

## 🔄 Updates and Maintenance

### Updating Lambda Code
```bash
# After modifying lambda/auth-handler.py
aws lambda update-function-code \
  --function-name secure-photo-downloader-auth-handler \
  --zip-file fileb://function.zip
```

### Updating CloudFormation Stacks
```bash
# Re-run deployment script for updates
./scripts/deploy.sh
```

### Backup Important Data
```bash
# Backup S3 bucket
aws s3 sync s3://your-bucket-name ./backup/

# Export Cognito users (if needed)
aws cognito-idp list-users --user-pool-id your-user-pool-id
```

## 🧹 Cleanup

### Complete Removal
```bash
# Remove all resources
./scripts/cleanup.sh
```

### Partial Cleanup
```bash
# Remove specific stack
aws cloudformation delete-stack --stack-name secure-photo-downloader-auth
```

## 🆘 Troubleshooting

### Common Issues

#### 1. Deployment Fails with Permission Errors
**Solution**: Ensure your AWS credentials have sufficient permissions
```bash
# Check current permissions
aws sts get-caller-identity
aws iam get-user
```

#### 2. Lambda Function Returns 500 Error
**Solution**: Check CloudWatch logs
```bash
aws logs tail /aws/lambda/secure-photo-downloader-auth-handler --follow
```

#### 3. S3 Access Denied
**Solution**: Verify bucket policy and IAM roles
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket your-bucket-name

# Check IAM role
aws iam get-role --role-name secure-photo-downloader-cognito-authenticated-role
```

#### 4. Cognito Authentication Fails
**Solution**: Verify Hosted UI configuration
```bash
# Check User Pool Client settings
aws cognito-idp describe-user-pool-client \
  --user-pool-id your-user-pool-id \
  --client-id your-client-id
```

#### 5. File Not Found Error
**Solution**: Ensure file exists in S3
```bash
# List bucket contents
aws s3 ls s3://your-bucket-name/photos/ --recursive

# Check if specific file exists
aws s3api head-object --bucket your-bucket-name --key photos/photos.zip
```

### Debug Mode
Enable debug logging by setting environment variable:
```bash
# In Lambda function
LOG_LEVEL=DEBUG
```

### Support Resources
- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)

## 📈 Scaling and Performance

### Performance Optimization
- Lambda memory can be increased for faster execution
- S3 Transfer Acceleration can be enabled for global users
- CloudFront can be added for caching static content

### Cost Optimization
- Use S3 Intelligent Tiering for automatic cost optimization
- Set appropriate Lambda memory allocation
- Configure log retention periods appropriately
- Monitor usage with AWS Cost Explorer

### High Availability
- Deploy across multiple regions if needed
- Use S3 Cross-Region Replication for backup
- Consider Lambda@Edge for global distribution

---

**Need Help?** Open an issue in the repository or check the troubleshooting section above.
