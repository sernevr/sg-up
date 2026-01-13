#!/bin/bash

# AWS Security Group Rule IP Updater
# Updates a specific security group inbound rule with current external IP
# SG found by description: Scripted-972151
# Rule found by description: Dev-551836

set -e

# Configuration
SG_DESCRIPTION="Scripted-972151"
RULE_DESCRIPTION="Dev-551836"
TARGET_PORT=3306

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "AWS Security Group Rule IP Updater"
echo "========================================"
echo ""

# Function to get external IP
get_external_ip() {
    local ip=""
    local providers=("ifconfig.me" "api.ipify.org" "icanhazip.com" "ipecho.net/plain")

    for provider in "${providers[@]}"; do
        ip=$(curl -s --connect-timeout 5 "$provider" 2>/dev/null | tr -d '[:space:]')
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    echo ""
    return 1
}

# Function to test TCP connection
test_tcp_connection() {
    local ip=$1
    local port=$2
    local timeout=5

    echo -e "${YELLOW}Testing TCP connection to ${ip}:${port}...${NC}"

    if timeout "$timeout" bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
        echo -e "${GREEN}SUCCESS: TCP connection to ${ip}:${port} established${NC}"
        return 0
    else
        echo -e "${RED}ERROR: TCP connection to ${ip}:${port} failed${NC}"
        return 1
    fi
}

# Step 1: Get current external IP
echo "Step 1: Getting current external IP address..."
CURRENT_IP=$(get_external_ip)
if [ -z "$CURRENT_IP" ]; then
    echo -e "${RED}ERROR: Failed to get external IP address${NC}"
    exit 1
fi
echo -e "Current external IP: ${GREEN}${CURRENT_IP}${NC}"
echo ""

# Step 2: Find Security Group by description
echo "Step 2: Finding Security Group with description '${SG_DESCRIPTION}'..."
SG_RESULT=$(aws ec2 describe-security-groups \
    --filters "Name=description,Values=${SG_DESCRIPTION}" \
    --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' \
    --output json)

SG_COUNT=$(echo "$SG_RESULT" | jq 'length')

if [ "$SG_COUNT" -eq 0 ]; then
    echo -e "${RED}ERROR: No Security Group found with description '${SG_DESCRIPTION}'${NC}"
    exit 1
elif [ "$SG_COUNT" -gt 1 ]; then
    echo -e "${RED}ERROR: Multiple Security Groups ($SG_COUNT) found with description '${SG_DESCRIPTION}'${NC}"
    echo "Found Security Groups:"
    echo "$SG_RESULT" | jq -r '.[] | "  - ID: \(.[0]), Name: \(.[1]), VPC: \(.[2])"'
    exit 1
fi

SG_ID=$(echo "$SG_RESULT" | jq -r '.[0][0]')
SG_NAME=$(echo "$SG_RESULT" | jq -r '.[0][1]')
VPC_ID=$(echo "$SG_RESULT" | jq -r '.[0][2]')

echo -e "Found Security Group: ${GREEN}${SG_NAME}${NC} (${SG_ID}) in VPC ${VPC_ID}"
echo ""

# Step 3: Find the specific inbound rule by description
echo "Step 3: Finding inbound rule with description '${RULE_DESCRIPTION}'..."
RULES_RESULT=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=${SG_ID}" \
    --query "SecurityGroupRules[?Description=='${RULE_DESCRIPTION}' && IsEgress==\`false\`].[SecurityGroupRuleId,CidrIpv4,FromPort,ToPort,IpProtocol]" \
    --output json)

RULE_COUNT=$(echo "$RULES_RESULT" | jq 'length')

if [ "$RULE_COUNT" -eq 0 ]; then
    echo -e "${RED}ERROR: No inbound rule found with description '${RULE_DESCRIPTION}'${NC}"
    exit 1
elif [ "$RULE_COUNT" -gt 1 ]; then
    echo -e "${RED}ERROR: Multiple inbound rules ($RULE_COUNT) found with description '${RULE_DESCRIPTION}'${NC}"
    echo "Found rules:"
    echo "$RULES_RESULT" | jq -r '.[] | "  - Rule ID: \(.[0]), CIDR: \(.[1]), Ports: \(.[2])-\(.[3]), Protocol: \(.[4])"'
    exit 1
fi

RULE_ID=$(echo "$RULES_RESULT" | jq -r '.[0][0]')
OLD_CIDR=$(echo "$RULES_RESULT" | jq -r '.[0][1]')
FROM_PORT=$(echo "$RULES_RESULT" | jq -r '.[0][2]')
TO_PORT=$(echo "$RULES_RESULT" | jq -r '.[0][3]')
PROTOCOL=$(echo "$RULES_RESULT" | jq -r '.[0][4]')

# Extract old IP from CIDR (remove /32 or similar suffix)
OLD_IP=$(echo "$OLD_CIDR" | cut -d'/' -f1)

echo -e "Found rule: ${GREEN}${RULE_ID}${NC}"
echo "  - Current CIDR: ${OLD_CIDR}"
echo "  - Port range: ${FROM_PORT}-${TO_PORT}"
echo "  - Protocol: ${PROTOCOL}"
echo ""

# Step 4: Update the security group rule
NEW_CIDR="${CURRENT_IP}/32"

echo "Step 4: Updating security group rule..."
echo "========================================"
echo -e "Old IP: ${RED}${OLD_IP}${NC} (${OLD_CIDR})"
echo -e "New IP: ${GREEN}${CURRENT_IP}${NC} (${NEW_CIDR})"
echo "========================================"

if [ "$OLD_CIDR" == "$NEW_CIDR" ]; then
    echo -e "${YELLOW}INFO: IP address is already up to date. No changes needed.${NC}"
else
    echo "Applying update..."
    aws ec2 modify-security-group-rules \
        --group-id "$SG_ID" \
        --security-group-rules "SecurityGroupRuleId=${RULE_ID},SecurityGroupRule={IpProtocol=${PROTOCOL},FromPort=${FROM_PORT},ToPort=${TO_PORT},CidrIpv4=${NEW_CIDR},Description=${RULE_DESCRIPTION}}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS: Security group rule updated successfully${NC}"
    else
        echo -e "${RED}ERROR: Failed to update security group rule${NC}"
        exit 1
    fi
fi
echo ""

# Step 5: Test TCP connection to port 3306
echo "Step 5: Testing connectivity..."

# Get the target IP for connection test (this would typically be the resource protected by the SG)
# Since we're testing if our IP can reach the target, we need to know where to connect
# For now, we'll try to get any instance using this security group
echo "Looking for instances using this security group for connection test..."

INSTANCE_IP=$(aws ec2 describe-instances \
    --filters "Name=instance.group-id,Values=${SG_ID}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[PublicIpAddress,PrivateIpAddress]' \
    --output json | jq -r '.[0][0] | if .[0] != null then .[0] else .[1] end' 2>/dev/null)

if [ -n "$INSTANCE_IP" ] && [ "$INSTANCE_IP" != "null" ]; then
    echo "Found instance with IP: ${INSTANCE_IP}"
    test_tcp_connection "$INSTANCE_IP" "$TARGET_PORT" || true
else
    echo -e "${YELLOW}INFO: No running instances found using this security group.${NC}"
    echo -e "${YELLOW}TCP connection test skipped - no target instance available.${NC}"
fi

echo ""
echo "========================================"
echo -e "${GREEN}Script completed successfully${NC}"
echo "========================================"
