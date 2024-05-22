#!/bin/bash

# Enhanced Output & Error Handling (with timestamps, colors, log levels, and emojis for fun)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
TICK="✅"
CROSS="❌"
INFO="ℹ️"

log_debug()   { [[ "$LOG_LEVEL" == "debug" ]] && echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${YELLOW}[DEBUG]${NC}  $1"; }
log_info()    { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${GREEN}[INFO]${NC}  $INFO $1"; }
log_success() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $TICK $1"; }
log_warn()    { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${NC} ⚠️ $1"; }
error_exit()  { echo -e "$(date +'%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $CROSS $1" >&2; exit 1; }

# Highly Customizable Configuration (with sensible defaults and explanations)
LOG_LEVEL="${LOG_LEVEL:-info}"             # Set to "debug" for extra verbosity
DEFAULT_IMAGE_NAME="my-app"
DEFAULT_DOCKERFILE="Dockerfile"
DEFAULT_BUILD_CONTEXT="."
PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY:-false}"     
REGISTRY_URL="${REGISTRY_URL:-your-registry.com}" # Placeholder, replace with your actual registry
CACHE_FROM_LATEST="${CACHE_FROM_LATEST:-true}"     
PLATFORM="${PLATFORM}"                  # Leave empty for automatic platform detection
BUILD_ARGS_FILE="${BUILD_ARGS_FILE}"           
ADDITIONAL_BUILD_OPTIONS="${ADDITIONAL_BUILD_OPTIONS}"  

# Input Handling (Command-Line Options, Environment Variables, Interactive Prompts)
while getopts ":n:f:c:p:r:l:x:b:a:" opt; do
    case $opt in
        n) IMAGE_NAME="$OPTARG";;
        f) DOCKERFILE="$OPTARG";;
        c) BUILD_CONTEXT="$OPTARG";;
        p) PUSH_TO_REGISTRY="$OPTARG";;
        r) REGISTRY_URL="$OPTARG";;
        l) LOG_LEVEL="$OPTARG";;
        x) PLATFORM="$OPTARG";;
        b) BUILD_ARGS_FILE="$OPTARG";;
        a) ADDITIONAL_BUILD_OPTIONS="$OPTARG";;
        \?) error_exit "Invalid option -$OPTARG. Usage: $0 [-n image_name] [-f Dockerfile] [-c build_context] [-p true/false] [-r registry_url] [-l log_level] [-x platform] [-b build_args_file] [-a additional_build_options]";;
    esac
done

# Fallback to Environment Variables (if options not provided)
IMAGE_NAME="${IMAGE_NAME:-$DOCKER_IMAGE_NAME}"
DOCKERFILE="${DOCKERFILE:-$DOCKER_DOCKERFILE}"
BUILD_CONTEXT="${BUILD_CONTEXT:-$DOCKER_BUILD_CONTEXT}"
PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY:-$DOCKER_PUSH_TO_REGISTRY}"
REGISTRY_URL="${REGISTRY_URL:-$DOCKER_REGISTRY_URL}"
LOG_LEVEL="${LOG_LEVEL:-$DOCKER_LOG_LEVEL}"
PLATFORM="${PLATFORM:-$DOCKER_PLATFORM}"
BUILD_ARGS_FILE="${BUILD_ARGS_FILE:-$DOCKER_BUILD_ARGS_FILE}"
ADDITIONAL_BUILD_OPTIONS="${ADDITIONAL_BUILD_OPTIONS:-$DOCKER_ADDITIONAL_BUILD_OPTIONS}"

# Interactive Prompts (as a last resort)
if [[ -z "$IMAGE_NAME" && -t 0 ]]; then
    read -p "Enter image name (default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
    IMAGE_NAME="${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}"
fi

# ... (Previous code remains the same, up to interactive prompts for IMAGE_NAME) ...

if [[ -z "$DOCKERFILE" && -t 0 ]]; then
    read -p "Enter Dockerfile path (default: $DEFAULT_DOCKERFILE): " DOCKERFILE
    DOCKERFILE="${DOCKERFILE:-$DEFAULT_DOCKERFILE}"
fi

if [[ -z "$BUILD_CONTEXT" && -t 0 ]]; then
    read -p "Enter build context path (default: $DEFAULT_BUILD_CONTEXT): " BUILD_CONTEXT
    BUILD_CONTEXT="${BUILD_CONTEXT:-$DEFAULT_BUILD_CONTEXT}"
fi

if [[ -z "$PUSH_TO_REGISTRY" && -t 0 ]]; then
    read -p "Push to registry? (true/false, default: false): " PUSH_TO_REGISTRY
    PUSH_TO_REGISTRY="${PUSH_TO_REGISTRY:-false}"
fi

if [[ "$PUSH_TO_REGISTRY" == "true" && -z "$REGISTRY_URL" && -t 0 ]]; then
    read -p "Enter registry URL: " REGISTRY_URL
fi

if [[ -z "$LOG_LEVEL" && -t 0 ]]; then
    read -p "Enter log level (debug, info, warn, error, default: info): " LOG_LEVEL
    LOG_LEVEL="${LOG_LEVEL:-info}"
fi

if [[ -z "$PLATFORM" && -t 0 ]]; then
    read -p "Enter target platform (e.g., linux/amd64, leave empty for auto-detect): " PLATFORM
fi

# Build Arguments (Interactive, File, Environment Variables, with Validation)
declare -A BUILD_ARGS=()
if [[ -n "$BUILD_ARGS_FILE" ]]; then
    log_info "Reading build arguments from file '$BUILD_ARGS_FILE'..."
    if [[ ! -f "$BUILD_ARGS_FILE" ]]; then
        error_exit "Build arguments file '$BUILD_ARGS_FILE' not found."
    fi
    while IFS="=" read -r key value; do
        BUILD_ARGS["$key"]="$value"
    done < "$BUILD_ARGS_FILE"
elif [[ -t 0 ]]; then
    log_info "Enter build arguments (key=value pairs, one per line, leave empty to finish):"
    while read -r line; do
        if [[ -z "$line" ]]; then break; fi
        if [[ ! "$line" =~ .*=.* ]]; then
            log_warn "Invalid build argument format. Please use 'key=value' format."
            continue
        fi
        key=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        BUILD_ARGS["$key"]="$value"
    done
else
    for var in "${!DOCKER_BUILD_ARG_@}"; do
        key="${var#DOCKER_BUILD_ARG_}"
        BUILD_ARGS["$key"]="${!var}"
    done
fi

# Build Command Construction (with dynamic options based on input)
log_info "Building Docker image '$IMAGE_NAME'..."
BUILD_COMMAND="docker build"

if [[ -n "$PLATFORM" ]]; then
    BUILD_COMMAND+=" --platform $PLATFORM"
fi

if [[ -n "$DOCKERFILE" ]]; then
    BUILD_COMMAND+=" -f $DOCKERFILE"
fi

BUILD_COMMAND+=" -t $IMAGE_NAME"

for key in "${!BUILD_ARGS[@]}"; do
    BUILD_COMMAND+=" --build-arg $key=${BUILD_ARGS[$key]}"
done

if [[ "$CACHE_FROM_LATEST" == "true" ]]; then
    BUILD_COMMAND+=" --cache-from $IMAGE_NAME:latest"
fi

BUILD_COMMAND+=" $ADDITIONAL_BUILD_OPTIONS $BUILD_CONTEXT"
log_debug "Full build command: $BUILD_COMMAND"

# Build Execution (with error handling and live output)
log_info "Executing Docker build..."
if ! $SUDO_CMD $BUILD_COMMAND; then
    error_exit "Docker build failed. Check the logs for details."
fi

# Push to Registry (if enabled)
if [[ "$PUSH_TO_REGISTRY" == "true" ]]; then
    log_info "Pushing image to registry '$REGISTRY_URL'..."
    if ! $SUDO_CMD docker push "$REGISTRY_URL/$IMAGE_NAME"; then
        error_exit "Docker push failed. Check the logs for details."
    fi
fi

# Verification (Check if the image exists locally)
log_info "Verifying built image..."
if $SUDO_CMD docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_success "Image '$IMAGE_NAME' built and verified successfully!"
else
    error_exit "Built image '$IMAGE_NAME' not found."
fi
