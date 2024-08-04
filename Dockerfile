# Use an official Python runtime as a parent image
FROM python:3.10-slim as base

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Install dependencies for running Chrome and other necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    xvfb \
    unzip \
    curl \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    software-properties-common && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and setup Chromium for ARM architecture
RUN wget https://github.com/macchrome/winchrome/releases/download/v110.0.5481.100-r1026311-Linux/bin-arm64.zip && \
    unzip bin-arm64.zip -d /usr/local/bin/chromium && \
    ln -s /usr/local/bin/chromium/chrome /usr/local/bin/chromium-browser && \
    rm bin-arm64.zip

# Set display port and dbus env to avoid hanging
ENV DISPLAY=:99
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Make port 80 available to the world outside this container
EXPOSE 80

# Define environment variable
ENV PYTHONUNBUFFERED 1

# Run uvicorn with more specific options
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
