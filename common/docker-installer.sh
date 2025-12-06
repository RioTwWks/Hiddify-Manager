#!/bin/bash

# Check if Docker is installed, if not, install it
command -v docker &>/dev/null || curl -fsSL https://get.docker.com | sh

# Set the default tag if not provided
TAG=${1:-latest}

# Function to detect the branch from which the script is being run
detect_branch() {
    local branch="main"  # Default branch
    
    # Try to detect branch from git repository
    if command -v git &>/dev/null; then
        # Check if we're in a git repository
        if git rev-parse --git-dir &>/dev/null; then
            # Get current branch
            local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
                branch="$current_branch"
                echo "Detected branch from git repository: $branch" >&2
            fi
        fi
    fi
    
    # Try to detect branch from script URL (if downloaded via curl)
    # Check if script was downloaded from a specific branch URL
    if [ -n "$SCRIPT_SOURCE_URL" ]; then
        if echo "$SCRIPT_SOURCE_URL" | grep -qE '/blob/([^/]+)/|/tree/([^/]+)/'; then
            local url_branch=$(echo "$SCRIPT_SOURCE_URL" | sed -nE 's|.*/(blob|tree)/([^/]+)/.*|\2|p' | head -1)
            if [ -n "$url_branch" ]; then
                branch="$url_branch"
                echo "Detected branch from script URL: $branch" >&2
            fi
        fi
    fi
    
    echo "$branch"
}

# Check if the 'hiddify-manager' folder exists
if [ -d "hiddify-manager" ]; then
    echo 'Folder "hiddify-manager" already exists. Please change the directory to install with Docker.'
    exit 1
fi

# Download the docker-compose.yml file or clone the project if it's on dev
if [[ "$TAG" == "develop" || "$TAG" == "dev" ]]; then
    # Check if Git is installed, if not, install it
    command -v git &>/dev/null || (echo "Installing Git..."; sudo apt-get update && sudo apt-get install -y git)
    git clone https://github.com/RioTwWks/Hiddify-Manager.git
    cd Hiddify-Manager
    git submodule update --init --recursive
    git submodule update --recursive --remote
    docker compose -f docker-compose.yml build
else
  # Create the 'hiddify-manager' directory
  mkdir hiddify-manager
  cd hiddify-manager
  
  # Detect branch automatically
  DETECTED_BRANCH=$(detect_branch)
  echo "Using branch: $DETECTED_BRANCH for docker-compose.yml"
  
  # Download docker-compose.yml from the detected branch
  wget https://raw.githubusercontent.com/RioTwWks/Hiddify-Manager/refs/heads/$DETECTED_BRANCH/docker-compose.yml
fi

# Generate random passwords for MySQL and Redis
mysqlpassword=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c49; echo)
redispassword=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c49; echo)

# Update docker-compose.yml with the specified tag and passwords
sed -i "s/hiddify-manager:latest/hiddify-manager:$TAG/g" docker-compose.yml
echo "REDIS_PASSWORD=$redispassword"> docker.env
echo "MYSQL_PASSWORD=$mysqlpassword">> docker.env

# Start the containers using Docker Compose
docker compose pull
docker compose up -d 

# Follow the logs from the containers
docker compose logs -f