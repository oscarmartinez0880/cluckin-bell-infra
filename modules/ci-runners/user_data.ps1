<powershell>
# Windows Server 2022 GitHub Actions Runner Setup Script
# This script sets up Docker and the GitHub Actions runner on Windows

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Create log directory
$LogDir = "C:\RunnerSetup"
New-Item -ItemType Directory -Path $LogDir -Force

# Function to log messages
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Add-Content -Path "$LogDir\setup.log" -Value $logMessage
}

Write-Log "Starting GitHub Actions runner setup"

try {
    # Install Chocolatey
    Write-Log "Installing Chocolatey"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Install required packages
    Write-Log "Installing Git, 7zip, and other dependencies"
    choco install -y git 7zip curl

    # Enable Windows containers feature
    Write-Log "Enabling Windows containers feature"
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart

    # Install Docker
    Write-Log "Installing Docker"
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force

    # Start Docker service
    Write-Log "Starting Docker service"
    Start-Service Docker
    Set-Service -Name Docker -StartupType Automatic

    # Configure Docker for Windows containers
    Write-Log "Configuring Docker for Windows containers"
    & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon

    # Create runner directory
    $RunnerDir = "C:\actions-runner"
    New-Item -ItemType Directory -Path $RunnerDir -Force
    Set-Location $RunnerDir

    # Download GitHub Actions runner
    Write-Log "Downloading GitHub Actions runner"
    $RunnerVersion = "2.319.1"  # Latest stable version as of template creation
    $RunnerUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/actions-runner-win-x64-$RunnerVersion.zip"
    Invoke-WebRequest -Uri $RunnerUrl -OutFile "actions-runner.zip"
    
    # Extract runner
    Write-Log "Extracting GitHub Actions runner"
    Expand-Archive -Path "actions-runner.zip" -DestinationPath . -Force
    Remove-Item "actions-runner.zip"

    # GitHub App configuration
    $GitHubAppId = "${github_app_id}"
    $GitHubAppInstallationId = "${github_app_installation_id}"
    $GitHubAppPrivateKey = @"
${github_app_private_key}
"@
    
    # Save private key to file
    $PrivateKeyPath = "$RunnerDir\github-app-key.pem"
    $GitHubAppPrivateKey | Out-File -FilePath $PrivateKeyPath -Encoding ascii

    # Generate JWT token for GitHub App authentication
    Write-Log "Generating GitHub App JWT token"
    
    # Create JWT header and payload
    $Header = @{
        alg = "RS256"
        typ = "JWT"
    } | ConvertTo-Json -Compress
    
    $Now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $Payload = @{
        iat = $Now
        exp = $Now + 600  # Token expires in 10 minutes
        iss = $GitHubAppId
    } | ConvertTo-Json -Compress
    
    # Base64 encode header and payload
    $EncodedHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Header)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $EncodedPayload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    # Create signature using private key
    $StringToSign = "$EncodedHeader.$EncodedPayload"
    
    # Use openssl to create signature (install via chocolatey if needed)
    choco install -y openssl
    $env:PATH += ";C:\Program Files\OpenSSL-Win64\bin"
    
    $SignatureBytes = & openssl dgst -sha256 -sign $PrivateKeyPath -binary ([System.Text.Encoding]::UTF8.GetBytes($StringToSign))
    $EncodedSignature = [Convert]::ToBase64String($SignatureBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    $JwtToken = "$StringToSign.$EncodedSignature"

    # Get installation access token
    Write-Log "Getting GitHub App installation access token"
    $InstallationTokenUrl = "https://api.github.com/app/installations/$GitHubAppInstallationId/access_tokens"
    $Headers = @{
        "Authorization" = "Bearer $JwtToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $TokenResponse = Invoke-RestMethod -Uri $InstallationTokenUrl -Method POST -Headers $Headers
    $AccessToken = $TokenResponse.token

    # Get runner registration token
    Write-Log "Getting runner registration token"
    $RegistrationTokenUrl = "https://api.github.com/repos/${github_repository_allowlist}/actions/runners/registration-token"
    $Headers = @{
        "Authorization" = "token $AccessToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $RegTokenResponse = Invoke-RestMethod -Uri $RegistrationTokenUrl -Method POST -Headers $Headers
    $RegistrationToken = $RegTokenResponse.token

    # Configure runner
    Write-Log "Configuring GitHub Actions runner"
    $RunnerName = "${runner_name_prefix}-$env:COMPUTERNAME"
    $RunnerLabels = "${runner_labels}"
    $RunnerGroup = "${runner_group}"
    
    $ConfigArgs = @(
        "--url", "https://github.com/${github_repository_allowlist}"
        "--token", $RegistrationToken
        "--name", $RunnerName
        "--labels", $RunnerLabels
        "--runnergroup", $RunnerGroup
        "--work", "_work"
        "--replace"
        "--unattended"
    )
    
    & .\config.cmd @ConfigArgs

    # Install and start runner service
    Write-Log "Installing and starting runner service"
    & .\svc.sh install
    & .\svc.sh start

    # Clean up private key file
    Remove-Item $PrivateKeyPath -Force

    Write-Log "GitHub Actions runner setup completed successfully"

    # Test Docker installation
    Write-Log "Testing Docker installation"
    docker version
    docker run --rm mcr.microsoft.com/windows/nanoserver:ltsc2022 echo "Docker Windows containers working"

} catch {
    Write-Log "Error during setup: $($_.Exception.Message)"
    Write-Log "Full error: $($_.Exception | Out-String)"
    exit 1
}

Write-Log "Setup script completed"
</powershell>
<persist>true</persist>