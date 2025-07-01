# Secure Photo Downloader - AWS Serverless Authentication System

A secure, serverless photo download system using AWS Cognito authentication and S3 storage. Users authenticate through Cognito Hosted UI and receive secure, time-limited download links for their photos.

## 🏗️ Architecture

```
User → Cognito Hosted UI → Lambda Function → S3 Pre-signed URL → Secure Download
```

## 🔧 Components

- **AWS Cognito User Pool**: User authentication and management
- **AWS Cognito Identity Pool**: AWS credentials for authenticated users  
- **AWS Lambda**: Generates secure download links
- **AWS S3**: Secure photo storage with private access
- **AWS IAM**: Fine-grained permissions and security policies

## 🚀 Features

- ✅ Secure user authentication via Cognito Hosted UI
- ✅ Time-limited download links (configurable expiry)
- ✅ Private S3 bucket with zero public access
- ✅ Fully serverless architecture (no servers to manage)
- ✅ User-friendly download interface
- ✅ Comprehensive error handling and logging
- ✅ Cost-effective pay-per-use model

## 📋 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with valid credentials
- Basic understanding of AWS serverless services

## 🛠️ Quick Deployment

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd secure-photo-downloader
   ```

2. **Configure your settings**
   ```bash
   # Edit the configuration in scripts/deploy.sh
   # Set your email and preferred AWS region
   ```

3. **Run the deployment script**
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```

4. **Upload your photos to S3**
   ```bash
   aws s3 cp your-photos.zip s3://YOUR-BUCKET-NAME/photos/photos.zip
   ```

5. **Get your authentication URL**
   ```bash
   ./scripts/get-auth-url.sh
   ```

## 📖 Detailed Setup Guide

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for comprehensive deployment instructions and troubleshooting.

## 🔒 Security Features

- **Zero Trust Architecture**: All S3 objects are private by default
- **Time-Limited Access**: Download links expire automatically (default: 1 hour)
- **Authenticated Access Only**: Only verified users can access downloads
- **Least Privilege IAM**: Roles follow security best practices
- **Encrypted Storage**: S3 server-side encryption enabled
- **Audit Trail**: CloudWatch logging for all access attempts

## 🧪 Testing Your Deployment

1. Visit your Cognito Hosted UI URL (provided after deployment)
2. Sign up or sign in with your credentials
3. Complete email verification if required
4. You'll be redirected to the secure download page
5. Your photo download will begin automatically

## 📁 Project Structure

```
secure-photo-downloader/
├── README.md                    # Project overview and quick start
├── docs/
│   ├── DEPLOYMENT.md           # Detailed deployment guide
│   └── ARCHITECTURE.md         # System architecture and design
├── lambda/
│   ├── auth-handler.py         # Lambda function for authentication
│   └── requirements.txt        # Python dependencies
├── cloudformation/
│   ├── auth-stack.yaml         # Cognito authentication resources
│   ├── storage-stack.yaml      # S3 bucket and security policies
│   └── compute-stack.yaml      # Lambda function and IAM roles
└── scripts/
    ├── deploy.sh               # Main deployment automation
    ├── cleanup.sh              # Resource cleanup script
    └── get-auth-url.sh         # Retrieve authentication URL
```

## ⚙️ Configuration Options

The system supports various configuration options:

- **Download Expiry**: Configure link expiration time
- **File Types**: Support for various photo formats and archives
- **User Management**: Customize user pool settings
- **Regional Deployment**: Deploy to any AWS region
- **Custom Domains**: Optional custom domain configuration

## 💰 Cost Optimization

This serverless architecture is designed for cost efficiency:

- **Pay-per-use**: Only pay when users download photos
- **No idle costs**: No servers running 24/7
- **S3 Intelligent Tiering**: Automatic cost optimization for storage
- **Lambda efficiency**: Optimized function execution time

## 🔧 Customization

Easy to customize for your specific needs:

- **Branding**: Update UI colors and logos
- **File Types**: Support different file formats
- **User Flows**: Modify authentication workflows
- **Notifications**: Add email/SMS notifications
- **Analytics**: Integrate with AWS analytics services

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support & Troubleshooting

If you encounter issues:

1. Check the [troubleshooting guide](docs/DEPLOYMENT.md#troubleshooting)
2. Review CloudWatch logs for the Lambda function
3. Verify your AWS permissions and quotas
4. Open an issue with detailed error information

## 🏷️ Version

Current version: 1.0.0

## 🌟 Use Cases

Perfect for:
- **Event Photography**: Secure photo distribution for weddings, parties
- **Corporate Events**: Professional photo sharing with access control
- **Family Sharing**: Private photo albums with time-limited access
- **Client Deliverables**: Secure file delivery for creative professionals
- **Educational Content**: Controlled access to course materials

---

**Built with for secure, scalable photo sharing**


