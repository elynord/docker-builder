
# Docker Installation and Image Building Scripts 🚀

Copyright (c) 2024 Elynord/Elyani

This repository contains two enhanced shell scripts designed to streamline your Docker experience:

1. **`install_docker.sh`:**  A comprehensive script for installing Docker Engine, along with a curated set of complementary tools, and configuring it with optimized settings.

2. **`build-image.sh`:**  A highly customizable script for building Docker images from Dockerfiles, with options for pushing to registries, using build arguments, and more.

## Features ✨

### Installation Script 

* **Comprehensive Installation:**  Installs Docker Engine, Docker Compose, and a selection of essential tools for Docker development and management.
* **Optimized Configuration:**  Sets up Docker with recommended configurations for logging, storage, and experimental features.
* **User-Friendly:**  Guides you through the installation process with clear instructions and helpful tips.
* **Robust Error Handling:**  Includes error checks and recovery mechanisms to ensure a smooth installation.
* **Post-Installation Guidance:**  Provides a list of resources and next steps to help you get started with Docker.

### Image Building Script 

* **Highly Customizable:**  Offers a wide range of options for customizing the build process, including Dockerfile path, build context, target platform, and build arguments.
* **Push to Registry:**  Easily push your built images to Docker Hub or any other registry.
* **Build Argument Support:**  Pass build arguments to your Dockerfile through command-line options, environment variables, or an interactive prompt.
* **Caching:**  Leverages caching to speed up subsequent builds.
* **Detailed Logging:**  Provides detailed logs with timestamps and helpful messages to keep you informed about the build progress.

## Usage 🚀

### Installation

1. **Download:** Clone or download this repository to your system.
2. **Run:** Execute the installation script as root (or with `sudo`):
   ```bash
   ./install_docker.sh
   ```
3. **Follow Prompts:**  The script will guide you through the installation process.

### Image Building

1. **Prepare Dockerfile:** Create a `Dockerfile` in your project directory.
2. **Run:** Execute the image building script with desired options:
   ```bash
   ./build-image.sh -n my-image -f Dockerfile
   ```
   (Replace `my-image` with your desired image name and `Dockerfile` with the path to your Dockerfile.)
3. **Customize:** Use the available options to tailor the build process to your needs.

## Examples 💡

**Basic Image Build:**

```bash
./build-image.sh -n my-web-app
```

**Build with Custom Dockerfile and Context:**

```bash
./build-image.sh -n my-api -f ./backend/Dockerfile -c ./backend
```

**Build with Build Arguments:**

```bash
./build-image.sh -n my-app -b build-args.env
```

**Build and Push to Registry:**

```bash
./build-image.sh -n my-app -p true -r myregistry.io
```

Feel free to explore the scripts and customize them to fit your specific Docker workflows!
