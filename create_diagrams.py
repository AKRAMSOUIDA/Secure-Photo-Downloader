#!/usr/bin/env python3
"""
AWS Architecture Diagrams for Secure Photo Downloader
Creates professional diagrams showing the system architecture
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import Lambda
from diagrams.aws.storage import S3
from diagrams.aws.security import Cognito, IAM
from diagrams.aws.management import Cloudwatch
from diagrams.aws.integration import SQS
from diagrams.aws.general import User
from diagrams.aws.network import CloudFront, Route53
from diagrams.onprem.client import Users
from diagrams.onprem.network import Internet

def create_main_architecture():
    """Create the main system architecture diagram"""
    
    with Diagram("Secure Photo Downloader - Main Architecture", 
                 filename="diagrams/main_architecture", 
                 show=False,
                 direction="TB"):
        
        # Users
        users = Users("Users")
        
        with Cluster("AWS Cloud"):
            # Authentication Layer
            with Cluster("Authentication Layer"):
                cognito_user_pool = Cognito("User Pool\n(Authentication)")
                cognito_identity_pool = Cognito("Identity Pool\n(AWS Credentials)")
                hosted_ui = Route53("Hosted UI\n(OAuth)")
            
            # Compute Layer
            with Cluster("Compute Layer"):
                lambda_func = Lambda("Auth Handler\n(Python 3.11)")
                dlq = SQS("Dead Letter\nQueue")
            
            # Storage Layer
            with Cluster("Storage Layer"):
                s3_bucket = S3("Private S3 Bucket\n(Encrypted)")
            
            # Security Layer
            with Cluster("Security & Monitoring"):
                iam_role = IAM("IAM Roles\n(Least Privilege)")
                cloudwatch = Cloudwatch("CloudWatch\n(Logs & Metrics)")
        
        # Flow connections
        users >> Edge(label="1. Access") >> hosted_ui
        hosted_ui >> Edge(label="2. Authenticate") >> cognito_user_pool
        cognito_user_pool >> Edge(label="3. OAuth Code") >> lambda_func
        lambda_func >> Edge(label="4. Check File") >> s3_bucket
        s3_bucket >> Edge(label="5. Pre-signed URL") >> lambda_func
        lambda_func >> Edge(label="6. Download Page") >> users
        users >> Edge(label="7. Direct Download", style="dashed") >> s3_bucket
        
        # Security and monitoring connections
        cognito_user_pool >> cognito_identity_pool
        cognito_identity_pool >> iam_role
        lambda_func >> dlq
        lambda_func >> cloudwatch
        s3_bucket >> cloudwatch

def create_security_architecture():
    """Create security-focused architecture diagram"""
    
    with Diagram("Secure Photo Downloader - Security Architecture", 
                 filename="diagrams/security_architecture", 
                 show=False,
                 direction="LR"):
        
        user = User("User")
        
        with Cluster("Security Layers"):
            with Cluster("Layer 1: Network Security"):
                https = Route53("HTTPS/TLS\nEncryption")
            
            with Cluster("Layer 2: Authentication"):
                cognito = Cognito("AWS Cognito\nUser Pool")
                oauth = Route53("OAuth 2.0\nFlow")
            
            with Cluster("Layer 3: Authorization"):
                iam = IAM("IAM Roles\n& Policies")
                temp_creds = IAM("Temporary\nCredentials")
            
            with Cluster("Layer 4: Data Protection"):
                s3_encryption = S3("S3 Server-Side\nEncryption")
                presigned = S3("Time-Limited\nPre-signed URLs")
        
        # Security flow
        user >> https >> oauth >> cognito
        cognito >> iam >> temp_creds
        temp_creds >> presigned >> s3_encryption

def create_data_flow():
    """Create detailed data flow diagram"""
    
    with Diagram("Secure Photo Downloader - Data Flow", 
                 filename="diagrams/data_flow", 
                 show=False,
                 direction="TB"):
        
        user = Users("User")
        
        with Cluster("Authentication Flow"):
            step1 = Route53("1. Access\nHosted UI")
            step2 = Cognito("2. User\nAuthentication")
            step3 = Route53("3. OAuth\nCallback")
        
        with Cluster("Processing Flow"):
            step4 = Lambda("4. Lambda\nHandler")
            step5 = S3("5. File\nValidation")
            step6 = S3("6. Generate\nPre-signed URL")
        
        with Cluster("Download Flow"):
            step7 = Route53("7. HTML\nResponse")
            step8 = S3("8. Direct\nDownload")
        
        with Cluster("Monitoring"):
            logs = Cloudwatch("CloudWatch\nLogs")
            metrics = Cloudwatch("CloudWatch\nMetrics")
        
        # Flow connections
        user >> step1 >> step2 >> step3 >> step4
        step4 >> step5 >> step6 >> step7 >> user
        user >> Edge(label="Direct", style="dashed") >> step8
        
        # Monitoring connections
        step4 >> logs
        step4 >> metrics
        step8 >> logs

def create_deployment_architecture():
    """Create deployment and infrastructure diagram"""
    
    with Diagram("Secure Photo Downloader - Deployment Architecture", 
                 filename="diagrams/deployment_architecture", 
                 show=False,
                 direction="TB"):
        
        with Cluster("Infrastructure as Code"):
            with Cluster("CloudFormation Stacks"):
                auth_stack = Cognito("auth-stack.yaml\n(Cognito Resources)")
                compute_stack = Lambda("compute-stack.yaml\n(Lambda Resources)")
                storage_stack = S3("storage-stack.yaml\n(S3 Resources)")
        
        with Cluster("Deployment Process"):
            with Cluster("Phase 1: Compute"):
                lambda_deploy = Lambda("Lambda Function\n+ Execution Role")
                lambda_url = Route53("Function URL\n(Public Access)")
            
            with Cluster("Phase 2: Storage"):
                s3_deploy = S3("S3 Bucket\n+ Security Policies")
                s3_encryption = S3("Encryption\n+ Lifecycle")
            
            with Cluster("Phase 3: Authentication"):
                cognito_deploy = Cognito("User Pool\n+ Identity Pool")
                hosted_ui_deploy = Route53("Hosted UI\n+ Domain")
        
        with Cluster("Monitoring & Operations"):
            cloudwatch_deploy = Cloudwatch("CloudWatch\n+ Dashboards")
            dlq_deploy = SQS("Dead Letter Queue\n+ Error Handling")
        
        # Deployment dependencies
        compute_stack >> lambda_deploy >> lambda_url
        storage_stack >> s3_deploy >> s3_encryption
        auth_stack >> cognito_deploy >> hosted_ui_deploy
        
        # Integration
        lambda_deploy >> s3_deploy
        cognito_deploy >> lambda_url
        lambda_deploy >> cloudwatch_deploy
        lambda_deploy >> dlq_deploy

def create_cost_optimization():
    """Create cost optimization architecture diagram"""
    
    with Diagram("Secure Photo Downloader - Cost Optimization", 
                 filename="diagrams/cost_optimization", 
                 show=False,
                 direction="LR"):
        
        with Cluster("Serverless Benefits"):
            lambda_cost = Lambda("Lambda\nPay-per-execution")
            s3_cost = S3("S3\nPay-per-storage")
            cognito_cost = Cognito("Cognito\nPay-per-user")
        
        with Cluster("Cost Controls"):
            with Cluster("S3 Optimization"):
                lifecycle = S3("Lifecycle\nPolicies")
                intelligent_tier = S3("Intelligent\nTiering")
            
            with Cluster("Lambda Optimization"):
                memory_opt = Lambda("Memory\nOptimization")
                timeout_opt = Lambda("Timeout\nLimits")
            
            with Cluster("Monitoring"):
                cost_alerts = Cloudwatch("Cost\nAlerts")
                usage_metrics = Cloudwatch("Usage\nMetrics")
        
        # Cost flow
        lambda_cost >> memory_opt >> timeout_opt
        s3_cost >> lifecycle >> intelligent_tier
        cognito_cost >> usage_metrics >> cost_alerts

def main():
    """Create all architecture diagrams"""
    import os
    
    # Create diagrams directory
    os.makedirs("diagrams", exist_ok=True)
    
    print("🎨 Creating AWS Architecture Diagrams...")
    
    # Create all diagrams
    create_main_architecture()
    print("✅ Main Architecture diagram created")
    
    create_security_architecture()
    print("✅ Security Architecture diagram created")
    
    create_data_flow()
    print("✅ Data Flow diagram created")
    
    create_deployment_architecture()
    print("✅ Deployment Architecture diagram created")
    
    create_cost_optimization()
    print("✅ Cost Optimization diagram created")
    
    print("\n🎉 All diagrams created successfully!")
    print("📁 Check the 'diagrams/' directory for PNG files")
    print("📋 Diagrams created:")
    print("   • main_architecture.png - Overall system architecture")
    print("   • security_architecture.png - Security layers and controls")
    print("   • data_flow.png - Detailed data flow process")
    print("   • deployment_architecture.png - Infrastructure deployment")
    print("   • cost_optimization.png - Cost optimization strategies")

if __name__ == "__main__":
    main()
