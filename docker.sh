#!/bin/bash

# Enhanced Output & Error Handling (with timestamps and colors)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info()    { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${GREEN}[INFO]${NC}  $1"; }
log_success() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${NC} $1"; }
error_exit()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Root Check with Explanation and Alternative (if not root)
if [[ $EUID -ne 0 ]]; then
    log_warn "This script is best run as root. We'll try with sudo, but some features might be limited."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# System Update with Progress Bar and Estimated Time (if 'pv' and 'apt-get' support it)
log_info "Updating package lists... This might take a while."
if command -v pv &>/dev/null && apt-get --just-print upgrade | grep -q Upgrading; then
    apt-get update | pv -trep -s $(apt-get --just-print upgrade | wc -l) || error_exit "Package list update failed."
else
    $SUDO_CMD apt-get update || error_exit "Package list update failed."
fi

# Comprehensive Package Installation with Detailed Explanations
log_info "Installing Docker and a curated set of complementary tools..."
PACKAGES=(
    apt-transport-https ca-certificates curl gnupg lsb-release
    software-properties-common   # PPA management for seamless Docker updates
    docker-ce docker-ce-cli containerd.io docker-compose-plugin # Core Docker components
    python3 python3-pip        # For advanced Docker scripting, automation, and SDK usage
    vim git                     # For Dockerfile editing and version control
    htop iotop iftop           # System monitoring tools for container resource usage
    jq                         # JSON processor for working with Docker API responses
    dive                       # Tool for exploring the contents of Docker images layer by layer
    lazydocker                 # Terminal UI for managing Docker objects (containers, images, volumes, etc.)
)

$SUDO_CMD apt-get install -y "${PACKAGES[@]}" || error_exit "Failed to install some packages. Check the logs for details."

# Docker Repository Setup (Official, with Alternative Mirror for Faster Downloads)
log_info "Adding Docker's official GPG key and repository..."
if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null
else
    log_warn "Failed to download Docker's GPG key from the official source. Trying a mirror..."
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
$SUDO_CMD apt-get update || error_exit "Failed to update package lists after adding Docker repository."

# Docker Engine Installation and Configuration
log_info "Installing the latest stable Docker Engine..."
$SUDO_CMD apt-get install -y docker-ce docker-ce-cli containerd.io || error_exit "Docker Engine installation failed."

# Docker Service Management (Start, Enable, Status Check)
log_info "Starting and enabling the Docker service..."
$SUDO_CMD systemctl start docker || log_warn "Docker service failed to start. Manual intervention might be needed."
$SUDO_CMD systemctl enable docker || log_warn "Docker service failed to enable on boot. Please check manually."
if $SUDO_CMD systemctl is-active --quiet docker; then
    log_success "Docker service is active and running!"
else
    log_warn "Docker service might not be running correctly. Please check the status manually."
fi

# User Management (Adding Current User to 'docker' Group for Non-Root Usage)
if [[ -n "$SUDO_CMD" ]]; then  # Only if we're using sudo
    log_info "Adding your user ($USER) to the 'docker' group for non-root access..."
    $SUDO_CMD usermod -aG docker $USER || log_warn "Failed to add your user to the 'docker' group. You might need to run 'sudo usermod -aG docker $USER' manually and log out/in for changes to take effect."
    log_success "Now you can run Docker commands without sudo!"
fi

# Advanced Configuration (Optional, Comment Out if Not Needed)
log_info "Setting up advanced Docker configurations..."
DOCKER_CONFIG_FILE="/etc/docker/daemon.json"
if [[ ! -f "$DOCKER_CONFIG_FILE" ]]; then
    log_info "Creating Docker daemon configuration file..."
    $SUDO_CMD touch "$DOCKER_CONFIG_FILE"
fi

CONFIG_JSON=$(cat <<EOF
{
  "log-driver": "json-file",  # Recommended for easier log management
  "log-opts": {
    "max-size": "100m",      # Set log file size limit (adjust as needed)
    "max-file": "5"          # Keep a limited number of log files
  },
  "storage-driver": "overlay2", # Recommended for most modern systems
  "experimental": true          # Enable experimental features (optional, use with caution)
}
EOF
)

if ! grep -q experimental "$DOCKER_CONFIG_FILE"; then
    log_info "Updating Docker daemon configuration with additional options..."
    echo "$CONFIG_JSON" | $SUDO_CMD tee "$DOCKER_CONFIG_FILE" > /dev/null
    log_success "Docker daemon configuration updated!"
    log_info "Restarting Docker service to apply changes..."
    $SUDO_CMD systemctl restart docker || log_warn "Docker service failed to restart. Please check manually."
fi

# Verification and Examples
log_info "Verifying Docker installation..."
if $SUDO_CMD docker run hello-world; then
    log_success "Docker is working correctly! Let's run some examples:"

    log_info "Example 1: Running a simple Ubuntu container interactively..."
    $SUDO_CMD docker run -it ubuntu bash
    # (This will start a bash shell inside the Ubuntu container)

    log_info "Example 2: Running a multi-container application with Docker Compose..."
    # (Assumes you have a 'docker-compose.yml' file in the current directory)
    $SUDO_CMD docker-compose up -d

    # Build and Run Custom Image (build-image.sh)
    log_info "Building and running a custom Docker image using 'build-image.sh'..."
    if [[ -f "build-image.sh" ]]; then
        chmod +x build-image.sh  # Ensure the script is executable
        ./build-image.sh || log_warn "There was an issue building the custom image. Please check the 'build-image.sh' script and logs for details."
    else
        log_warn "The 'build-image.sh' script was not found in the current directory. Skipping this step."
    fi

else
    error_exit "Docker installation verification failed."
fi

# Post-Installation Tips and Next Steps
log_info "Docker installation and basic examples complete!"
echo -e "\n${GREEN}Here are some additional tips and resources to help you get the most out of Docker:${NC}\n"

echo "- **Explore Docker Hub:** Discover a vast library of official and community-maintained Docker images for various applications and services. Visit https://hub.docker.com/"
echo "- **Learn Docker Commands:** Master essential Docker commands like `docker run`, `docker ps`, `docker build`, and `docker-compose`. Check the official documentation at https://docs.docker.com/"
echo "- **Build Your Own Images:** Create custom Docker images using Dockerfiles to package your applications and dependencies. See the Dockerfile reference at https://docs.docker.com/engine/reference/builder/"
echo "- **Orchestrate with Docker Compose:** Define and manage multi-container applications easily with Docker Compose. Get started at https://docs.docker.com/compose/"
echo "- **Dive into Networking:** Understand Docker's networking concepts and how to connect containers and expose ports. Learn more at https://docs.docker.com/network/"
echo "- **Volumes for Data Persistence:** Use Docker volumes to store and share data between containers and across restarts. Explore volumes at https://docs.docker.com/storage/volumes/"
echo "- **Security Best Practices:** Follow security guidelines to protect your Docker environment. See https://docs.docker.com/engine/security/"
echo "- **Advanced Topics:** Delve into more advanced Docker features like secrets management, multi-stage builds, and Swarm mode for clustering."
echo "- **Troubleshooting Tips:** Find solutions to common Docker issues and errors. Check the troubleshooting guide at https://docs.docker.com/config/daemon/troubleshoot/"
echo "- **Community Support:** Join the Docker community forums and Slack channels to ask questions, share knowledge, and get help. Visit https://www.docker.com/community"

# Additional Resources
echo "\n${GREEN}Here are some excellent resources to expand your Docker knowledge:${NC}\n"
echo "- Docker Mastery Course: https://www.udemy.com/course/docker-mastery/"
echo "- Docker Deep Dive Book: https://www.manning.com/books/docker-in-practice-second-edition"
echo "- Docker Blog: https://www.docker.com/blog/"
echo "- Awesome Docker: A curated list of Docker resources and tools: https://github.com/veggiemonk/awesome-docker"

log_success "Happy Docking!"
