# sg-up - AWS Security Group Rule IP Updater

A bash script to automatically update an AWS Security Group inbound rule with your current external IP address.

## Overview

This script:
1. Gets your current external IP address
2. Updates the wanted rule's IP address (CIDR) with your current external IP
3. Displays old and new IP addresses

## Prerequisites

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

### AWS IAM Policy

The script requires the following minimum IAM permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupRules"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:ModifySecurityGroupRules",
            "Resource": "arn:aws:ec2:REGION:ACCOUNT_ID:security-group/SG_ID"
        }
    ]
}
```

Replace `REGION`, `ACCOUNT_ID`, and `SG_ID` with your values (e.g., `arn:aws:ec2:us-east-1:123456789012:security-group/sg-0abc123def456`).

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/sernevr/sg-up.git
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

Step 2: Finding Security Group with description 'your-sg-description'...
Found Security Group: my-security-group (sg-0123456789abcdef0) in VPC vpc-abcdef01

Step 3: Finding inbound rule with description 'your-rule-description'...
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

========================================
Script completed successfully
========================================
```

## Error Handling

The script will exit with an error in the following cases:

- **No Security Group found**: No SG matches the configured description
- **Multiple Security Groups found**: More than one SG matches the description
- **No inbound rule found**: No rule matches the configured description
- **Multiple inbound rules found**: More than one rule matches the description
- **Failed to get external IP**: Unable to reach IP lookup services
- **AWS API errors**: Permission issues or network problems

## External IP Providers

The script tries these providers in order to get your external IP:
1. ifconfig.me
2. api.ipify.org
3. icanhazip.com
4. ipecho.net/plain

## License

See [LICENSE](LICENSE) file for details.
