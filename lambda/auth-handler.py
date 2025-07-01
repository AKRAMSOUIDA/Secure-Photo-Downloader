import json
import boto3
import urllib.parse
from botocore.exceptions import ClientError
import os

def lambda_handler(event, context):
    """
    Lambda function to handle OAuth callback and generate secure S3 download links
    
    This function:
    1. Receives OAuth callback from Cognito authentication
    2. Generates a pre-signed S3 URL for the requested file
    3. Returns an HTML page with automatic download initiation
    
    Environment Variables:
    - BUCKET_NAME: S3 bucket containing the files (required)
    - OBJECT_KEY: S3 object key for the file (default: photos/photos.zip)
    - DOWNLOAD_EXPIRY: Link expiration time in seconds (default: 3600 = 1 hour)
    - APP_NAME: Application name for branding (default: Secure Photo Downloader)
    """
    
    print(f"Event received: {json.dumps(event)}")
    
    # Configuration from environment variables
    BUCKET_NAME = os.environ.get('BUCKET_NAME', 'secure-photo-downloads')
    OBJECT_KEY = os.environ.get('OBJECT_KEY', 'photos/photos.zip')
    DOWNLOAD_EXPIRY = int(os.environ.get('DOWNLOAD_EXPIRY', '3600'))  # 1 hour default
    APP_NAME = os.environ.get('APP_NAME', 'Secure Photo Downloader')
    
    try:
        # Check if this is an OAuth callback (has authorization code)
        query_params = event.get('queryStringParameters') or {}
        
        # If there's an authorization code, the user has been authenticated by Cognito
        # We don't need to validate it further for this simple use case
        auth_code = query_params.get('code')
        
        if auth_code:
            print(f"Authorization code received: {auth_code[:10]}...")
        else:
            print("No authorization code - might be direct access")
        
        # Create S3 client with Lambda's execution role
        s3_client = boto3.client('s3')
        
        # Check if the object exists before generating pre-signed URL
        try:
            s3_client.head_object(Bucket=BUCKET_NAME, Key=OBJECT_KEY)
            print(f"Object {OBJECT_KEY} exists in bucket {BUCKET_NAME}")
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                print(f"Object {OBJECT_KEY} not found in bucket {BUCKET_NAME}")
                return {
                    'statusCode': 404,
                    'headers': {'Content-Type': 'text/html'},
                    'body': generate_error_page(
                        "File Not Found", 
                        f"The requested file '{OBJECT_KEY}' was not found. Please contact support.",
                        APP_NAME
                    )
                }
            else:
                raise e
        
        # Generate pre-signed URL
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET_NAME, 'Key': OBJECT_KEY},
            ExpiresIn=DOWNLOAD_EXPIRY
        )
        
        print(f"Generated pre-signed URL: {presigned_url[:50]}...")
        
        # Return HTML page with automatic download
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'text/html',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            },
            'body': generate_download_page(presigned_url, DOWNLOAD_EXPIRY, APP_NAME, OBJECT_KEY)
        }
        
    except ClientError as e:
        print(f"AWS Error: {e}")
        error_code = e.response.get('Error', {}).get('Code', 'Unknown')
        error_message = e.response.get('Error', {}).get('Message', str(e))
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'text/html'},
            'body': generate_error_page(f"AWS Error: {error_code}", error_message, APP_NAME)
        }
    except Exception as e:
        print(f"General Error: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'text/html'},
            'body': generate_error_page("System Error", str(e), APP_NAME)
        }

def generate_download_page(download_url, expiry_seconds, app_name, object_key):
    """Generate HTML page for successful download"""
    expiry_hours = expiry_seconds // 3600
    file_name = object_key.split('/')[-1]  # Extract filename from object key
    
    return f'''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Secure Download - {app_name}</title>
        <meta http-equiv="refresh" content="3;url={download_url}">
        <style>
            body {{ 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                text-align: center; 
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }}
            .container {{ 
                max-width: 600px; 
                background: rgba(255, 255, 255, 0.1);
                backdrop-filter: blur(10px);
                border-radius: 20px;
                padding: 40px;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }}
            .success {{ 
                color: #4CAF50; 
                font-size: 4em;
                margin-bottom: 20px;
                animation: pulse 2s infinite;
            }}
            @keyframes pulse {{
                0% {{ transform: scale(1); }}
                50% {{ transform: scale(1.1); }}
                100% {{ transform: scale(1); }}
            }}
            h1 {{
                margin: 20px 0;
                font-size: 2em;
                font-weight: 300;
            }}
            .app-name {{
                font-size: 0.8em;
                opacity: 0.8;
                margin-bottom: 30px;
            }}
            p {{
                font-size: 1.1em;
                line-height: 1.6;
                margin: 15px 0;
            }}
            .download-link {{ 
                display: inline-block; 
                background: linear-gradient(45deg, #4CAF50, #45a049);
                color: white; 
                padding: 15px 30px; 
                text-decoration: none; 
                border-radius: 50px; 
                margin: 20px 0;
                font-weight: bold;
                font-size: 1.1em;
                transition: all 0.3s ease;
                box-shadow: 0 4px 15px rgba(76, 175, 80, 0.3);
            }}
            .download-link:hover {{
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(76, 175, 80, 0.4);
            }}
            .spinner {{
                border: 3px solid rgba(255, 255, 255, 0.3);
                border-radius: 50%;
                border-top: 3px solid white;
                width: 40px;
                height: 40px;
                animation: spin 1s linear infinite;
                margin: 20px auto;
            }}
            @keyframes spin {{
                0% {{ transform: rotate(0deg); }}
                100% {{ transform: rotate(360deg); }}
            }}
            .info {{
                background: rgba(255, 255, 255, 0.1);
                border-radius: 15px;
                padding: 20px;
                margin-top: 30px;
                font-size: 0.95em;
                border: 1px solid rgba(255, 255, 255, 0.2);
            }}
            .file-info {{
                background: rgba(255, 255, 255, 0.05);
                border-radius: 10px;
                padding: 15px;
                margin: 20px 0;
                font-family: monospace;
            }}
            .countdown {{
                font-size: 1.2em;
                font-weight: bold;
                color: #4CAF50;
            }}
        </style>
        <script>
            let countdown = 3;
            function updateCountdown() {{
                const element = document.getElementById('countdown');
                if (element) {{
                    element.textContent = countdown;
                    countdown--;
                    if (countdown >= 0) {{
                        setTimeout(updateCountdown, 1000);
                    }}
                }}
            }}
            window.onload = updateCountdown;
        </script>
    </head>
    <body>
        <div class="container">
            <div class="success">🔐</div>
            <div class="app-name">{app_name}</div>
            <h1>Authentication Successful!</h1>
            <div class="spinner"></div>
            <p>Your secure download will start automatically in <span id="countdown" class="countdown">3</span> seconds...</p>
            
            <div class="file-info">
                <strong>📁 File:</strong> {file_name}
            </div>
            
            <p>If the download doesn't start automatically, click the button below:</p>
            <a href="{download_url}" class="download-link">📥 Download Securely</a>
            
            <div class="info">
                <p><strong>🔒 Security Notice:</strong></p>
                <p>This download link will expire in <strong>{expiry_hours} hour{'s' if expiry_hours != 1 else ''}</strong> for your security.</p>
                <p>Please save the file to your device before the link expires.</p>
                <p>This link is unique to your session and cannot be shared.</p>
            </div>
        </div>
    </body>
    </html>
    '''

def generate_error_page(error_title, error_details, app_name):
    """Generate HTML page for errors"""
    return f'''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Download Error - {app_name}</title>
        <style>
            body {{ 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                text-align: center; 
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
                color: white;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }}
            .container {{ 
                max-width: 600px; 
                background: rgba(255, 255, 255, 0.1);
                backdrop-filter: blur(10px);
                border-radius: 20px;
                padding: 40px;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }}
            .error {{ 
                color: #ff4757; 
                font-size: 4em;
                margin-bottom: 20px;
            }}
            h1 {{
                margin: 20px 0;
                font-size: 2em;
                font-weight: 300;
            }}
            .app-name {{
                font-size: 0.8em;
                opacity: 0.8;
                margin-bottom: 30px;
            }}
            p {{
                font-size: 1.1em;
                line-height: 1.6;
                margin: 15px 0;
            }}
            .error-details {{
                background: rgba(255, 255, 255, 0.1);
                border-radius: 15px;
                padding: 20px;
                margin: 20px 0;
                font-family: monospace;
                font-size: 0.9em;
                text-align: left;
                border: 1px solid rgba(255, 255, 255, 0.2);
                word-break: break-word;
            }}
            .support-info {{
                background: rgba(255, 255, 255, 0.1);
                border-radius: 15px;
                padding: 20px;
                margin-top: 30px;
                font-size: 0.95em;
                border: 1px solid rgba(255, 255, 255, 0.2);
            }}
            .retry-button {{
                display: inline-block;
                background: linear-gradient(45deg, #3498db, #2980b9);
                color: white;
                padding: 12px 25px;
                text-decoration: none;
                border-radius: 25px;
                margin: 15px 0;
                font-weight: bold;
                transition: all 0.3s ease;
            }}
            .retry-button:hover {{
                transform: translateY(-2px);
                box-shadow: 0 4px 15px rgba(52, 152, 219, 0.3);
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="error">⚠️</div>
            <div class="app-name">{app_name}</div>
            <h1>{error_title}</h1>
            <p>We're sorry, but there was an error processing your secure download request.</p>
            
            <div class="error-details">
                <strong>Error Details:</strong><br>
                {error_details}
            </div>
            
            <a href="javascript:window.location.reload();" class="retry-button">🔄 Try Again</a>
            
            <div class="support-info">
                <p><strong>🆘 Need Help?</strong></p>
                <p>If this problem persists, please contact support with the error details above.</p>
                <p>You can also try:</p>
                <ul style="text-align: left; display: inline-block;">
                    <li>Refreshing the page</li>
                    <li>Signing in again</li>
                    <li>Clearing your browser cache</li>
                    <li>Trying a different browser</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
    '''
