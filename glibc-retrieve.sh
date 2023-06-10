#!/bin/bash
### Extracts the libc and ld binaries from a Dockerfile
### Usage: ./extract-glibc.sh Dockerfile output_directory
### author: jackfromeast


IMAGE_NAME="temp_image"             # Docker image name
CONTAINER_NAME="temp_container"     # Docker container name

DOCKERFILE=$1                       # Dockerfile path 
OUTPUT_DIR=$2                       # Output directory

if [[ -z "$DOCKERFILE" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 Dockerfile output_directory"
    exit 1
fi

# Check whether the docker image and container already exist
if [ $(docker ps -a -q -f name=$CONTAINER_NAME) ]; then
    echo -e "\e[32m[+] Docker container $CONTAINER_NAME already exists. Removing...\e[0m"
    docker rm -f $CONTAINER_NAME
fi
if [ $(docker images -q $IMAGE_NAME) ]; then
    echo -e "\e[32m[+] Docker image $IMAGE_NAME already exists. Removing...\e[0m"
    docker rmi -f $IMAGE_NAME
fi

# Build the Docker image
echo -e "\e[32m[+] Building docker image from $DOCKERFILE...\e[0m"
docker build -t $IMAGE_NAME -f $DOCKERFILE . || { echo -e "\e[31m[!] Docker build failed\e[0m"; exit 1; }

# Create and run the container in the background
echo -e "\e[32m[+] Running docker container $CONTAINER_NAME...\e[0m"
docker run -d --name $CONTAINER_NAME $IMAGE_NAME tail -f /dev/null || { echo "\e[31m[!] Docker run failed\e[0m"; exit 1; }

# Create the output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Firstly, we try the common name for the glibc to find the libc binary
# Glibc binaries are usually named libc-*.so or libc.so.6
LIBC_BINARY_PATH=$(docker exec $CONTAINER_NAME sh -c 'find / -name "libc-*.so" -type f -print -quit 2>/dev/null')
if [[ -z "$LIBC_BINARY_PATH" ]]; then
    LIBC_BINARY_PATH=$(docker exec $CONTAINER_NAME sh -c 'find / -name "libc.so.6" -type f -print -quit 2>/dev/null')
fi

# Next, if the libc binary still isn't found, use the ldd command
# If the binary has been placed in a jail, ldd usually cannot be found
if [[ -z "$LIBC_BINARY_PATH" ]]; then
    echo -e "\e[32m[!] libc library not found with 'find', trying 'ldd'...\e[0m"
    docker exec $CONTAINER_NAME sh -c 'apt update && apt-get install -y ldd'
    LIBC_BINARY_PATH=$(docker exec $CONTAINER_NAME sh -c 'ldd /bin/sh | grep libc.so | cut -d " " -f 3')
    if [[ -n "$LIBC_BINARY_PATH" ]]; then
        # Resolve the symlink to the actual binary
        LIBC_BINARY_PATH=$(docker exec $CONTAINER_NAME sh -c "readlink -f $LIBC_BINARY_PATH")
    fi
fi

# If the libc binary still isn't found, exit with an error
if [[ -z "$LIBC_BINARY_PATH" ]]; then
    echo -e "\e[31m[!] Cannot find the glibc library.\e[0m"
    exit 1
fi


# Extract the filename from the binary path
LIBC_BINARY_NAME=$(basename $LIBC_BINARY_PATH)

# Copy the libc binary to the output directory
echo -e "\e[32m[+] Copying glibc binary to $OUTPUT_DIR\e[0m"
docker cp "$CONTAINER_NAME:$LIBC_BINARY_PATH" "$OUTPUT_DIR/$LIBC_BINARY_NAME" || { echo -e "\e[31mCopying libc binary failed\e[0m"; exit 1; }

# Get the real path of the ld binary
LD_BINARY_PATH=$(docker exec $CONTAINER_NAME sh -c 'find / -name "ld-linux*.so*" -type f -type f -print -quit 2>/dev/null')
if [[ -z "$LD_BINARY_PATH" ]]; then
    echo -e "\e[31m[!] Cannot found the ld library.\e[0m"
    exit 1
fi

# Extract the filename from the binary path
LD_BINARY_NAME=$(basename $LD_BINARY_PATH)

# Copy the ld binary to the output directory
echo -e "\e[32m[+] Copying ld binary to $OUTPUT_DIR\e[0m"
docker cp "$CONTAINER_NAME:$LD_BINARY_PATH" "$OUTPUT_DIR/$LD_BINARY_NAME" || { echo "\e[31mCopying ld binary failed\e[0m"; exit 1; }

# Stop and remove the container
echo -e "\e[32m[+] Cleaning up the temp docker image and container...\e[0m"
docker stop $CONTAINER_NAME || { echo -e "\e[31m[!] Stopping container failed\e[0m"; exit 1; }
docker rm $CONTAINER_NAME || { echo -e "\e[31m[!] Removing container failed\e[0m"; exit 1; }

# Remove the image
docker rmi -f $IMAGE_NAME || { echo -e "\e[31m[!] Removing Docker image failed\e[0m"; exit 1; }
