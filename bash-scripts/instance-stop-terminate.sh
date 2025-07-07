# Script Was used to stop or terminate based on your choose
#!/bin/bash

# Script to list running EC2 instances, choose by number, and stop or terminate with confirmation

# Ensure AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "AWS CLI is not configured. Please run 'aws configure' first."
  exit 1
fi

# Fetch only running EC2 instances
echo "Fetching running EC2 instances..."
INSTANCE_DETAILS=$(aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].[InstanceId, Tags[?Key=='Name'].Value | [0], State.Name]" \
  --output text | awk '$3 == "running"')

if [ -z "$INSTANCE_DETAILS" ]; then
  echo "No running EC2 instances found."
  exit 0
fi

# Display instances with numbering
echo "Available Running EC2 Instances:"
IFS=$'\n' read -rd '' -a INSTANCE_ARRAY <<<"$INSTANCE_DETAILS"

for i in "${!INSTANCE_ARRAY[@]}"; do
  INSTANCE_ID=$(echo "${INSTANCE_ARRAY[$i]}" | awk '{print $1}')
  INSTANCE_NAME=$(echo "${INSTANCE_ARRAY[$i]}" | awk '{print $2}')
  INSTANCE_STATE=$(echo "${INSTANCE_ARRAY[$i]}" | awk '{print $3}')
  printf "%d) Instance ID: %s | Name: %s | State: %s\n" "$((i+1))" "$INSTANCE_ID" "$INSTANCE_NAME" "$INSTANCE_STATE"
done

# Ask user for selection
read -p "Enter the numbers of the instances you want to manage (space-separated): " -a SELECTIONS

# Validate and collect instance IDs
SELECTED_IDS=()
for num in "${SELECTIONS[@]}"; do
  if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#INSTANCE_ARRAY[@]}" ]; then
    echo "Invalid selection: $num"
    exit 1
  fi
  IDX=$((num - 1))
  INSTANCE_ID=$(echo "${INSTANCE_ARRAY[$IDX]}" | awk '{print $1}')
  SELECTED_IDS+=("$INSTANCE_ID")
done

# Show action menu
echo "Choose an action:"
echo "1) Stop selected instances"
echo "2) Terminate selected instances"
read -p "Enter your choice (1 or 2): " ACTION

# Confirm and execute
if [ "$ACTION" == "1" ]; then
  echo "You are about to STOP the following instances: ${SELECTED_IDS[*]}"
  read -p "Are you sure? (y/n): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    aws ec2 stop-instances --instance-ids "${SELECTED_IDS[@]}"
  else
    echo "Operation cancelled."
  fi
elif [ "$ACTION" == "2" ]; then
  echo "You are about to TERMINATE the following instances: ${SELECTED_IDS[*]}"
  read -p "Are you sure? (y/n): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    aws ec2 terminate-instances --instance-ids "${SELECTED_IDS[@]}"
  else
    echo "Operation cancelled."
  fi
else
  echo "Invalid action selected."
  exit 1
fi