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

# Install Chromium for ARM architecture using a more reliable source
RUN wget https://download-chromium.appspot.com/dl/Linux_arm64 -O chromium.zip && \
    unzip chromium.zip -d /usr/local/bin/chromium && \
    ln -s /usr/local/bin/chromium/chrome /usr/local/bin/chromium-browser && \
    rm chromium.zip

# Set display port and dbus env to avoid hanging
ENV DISPLAY=:99
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Make port 80 available to the world outside this container
EXPOSE 80

# Define environment variable
ENV PYTHONUNBUFFERED 1

# Run uvicorn with more specific options
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
