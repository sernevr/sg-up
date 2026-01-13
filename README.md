# sg-up - AWS Security Group Rule IP Updater

A bash script to automatically update an AWS Security Group inbound rule with your current external IP address.

## Overview

This script:
1. Finds a Security Group by its description (`Scripted-972151`)
2. Finds an inbound rule within that Security Group by rule description (`Dev-551836`)
3. Gets your current external IP address
4. Updates the rule's IP address (CIDR) with your current external IP
5. Displays old and new IP addresses
6. Tests TCP connectivity to port 3306 (if an instance is found using the SG)

## Prerequisites

### AWS CLI

The script requires AWS CLI v2. Install using your package manager or from AWS:

**Ubuntu/Debian:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Windows:**
Download and run the installer from: https://awscli.amazonaws.com/AWSCLIV2.msi

### jq (JSON Processor)

**Ubuntu/Debian:**
```bash
sudo apt-get update && sudo apt-get install -y jq
```

**macOS:**
```bash
brew install jq
```

**Windows (using Chocolatey):**
```bash
choco install jq
```

### curl

Usually pre-installed on most systems. If not:

**Ubuntu/Debian:**
```bash
sudo apt-get install -y curl
```

**macOS:**
```bash
brew install curl
```

## AWS Configuration

The script uses the **default** AWS profile. Configure it with:

```bash
aws configure
```

You will need to provide:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (recommended: `json`)

### Required IAM Permissions

The IAM user/role needs the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupRules",
                "ec2:ModifySecurityGroupRules",
                "ec2:DescribeInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

## Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd sg-up
   ```

2. Make the script executable:
   ```bash
   chmod +x update-sg-rule.sh
   ```

## Usage

Simply run the script:

```bash
./update-sg-rule.sh
```

### Example Output

```
========================================
AWS Security Group Rule IP Updater
========================================

Step 1: Getting current external IP address...
Current external IP: 203.0.113.42

Step 2: Finding Security Group with description 'Scripted-972151'...
Found Security Group: my-security-group (sg-0123456789abcdef0) in VPC vpc-abcdef01

Step 3: Finding inbound rule with description 'Dev-551836'...
Found rule: sgr-0123456789abcdef0
  - Current CIDR: 198.51.100.1/32
  - Port range: 3306-3306
  - Protocol: tcp

Step 4: Updating security group rule...
========================================
Old IP: 198.51.100.1 (198.51.100.1/32)
New IP: 203.0.113.42 (203.0.113.42/32)
========================================
Applying update...
SUCCESS: Security group rule updated successfully

Step 5: Testing connectivity...
Looking for instances using this security group for connection test...
Found instance with IP: 54.123.45.67
Testing TCP connection to 54.123.45.67:3306...
SUCCESS: TCP connection to 54.123.45.67:3306 established

========================================
Script completed successfully
========================================
```

## Error Handling

The script will exit with an error in the following cases:

- **No Security Group found**: No SG matches the description `Scripted-972151`
- **Multiple Security Groups found**: More than one SG matches the description
- **No inbound rule found**: No rule matches the description `Dev-551836`
- **Multiple inbound rules found**: More than one rule matches the description
- **Failed to get external IP**: Unable to reach IP lookup services
- **AWS API errors**: Permission issues or network problems

## Configuration

To change the Security Group or rule descriptions, edit these variables in `update-sg-rule.sh`:

```bash
SG_DESCRIPTION="Scripted-972151"
RULE_DESCRIPTION="Dev-551836"
TARGET_PORT=3306
```

## External IP Providers

The script tries these providers in order to get your external IP:
1. ifconfig.me
2. api.ipify.org
3. icanhazip.com
4. ipecho.net/plain

## License

See [LICENSE](LICENSE) file for details.
