# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Install dependencies for Chrome and ChromeDriver
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    xvfb \
    unzip \
    curl \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    software-properties-common

# Download precompiled Chromium and ChromeDriver for aarch64
RUN wget https://download-chromium.appspot.com/dl/Linux_arm64?type=snapshots -O chromium.zip && \
    unzip chromium.zip -d /usr/local/bin/chromium && \
    ln -s /usr/local/bin/chromium/chrome /usr/local/bin/chromium-browser

RUN wget https://chromedriver.storage.googleapis.com/114.0.5735.90/chromedriver_linux64.zip && \
    unzip chromedriver_linux64.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/chromedriver

# Install spacy library using pip
RUN pip install spacy

# Set display port and dbus env to avoid hanging
ENV DISPLAY=:99
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Make port 80 available to the world outside this container
EXPOSE 80

# Define environment variable
ENV PYTHONUNBUFFERED 1

# Run uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
