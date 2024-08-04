# First stage: Build and install dependencies
FROM python:3.10-slim-bookworm

# Set the working directory in the container
WORKDIR /usr/src/app

# Define build arguments
ARG INSTALL_OPTION=default

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    git \
    curl \
    unzip \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common && \
    rm -rf /var/lib/apt/lists/*

# Add Google Chrome's official GPG key and repository using the new method
RUN wget -q -O /usr/share/keyrings/google-chrome-keyring.gpg https://dl.google.com/linux/linux_signing_key.pub && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Copy the application code
COPY . .

# Install Crawl4AI using the local setup.py with the specified option
RUN if [ "$INSTALL_OPTION" = "all" ]; then \
        pip install --no-cache-dir .[all] && \
        crawl4ai-download-models; \
    elif [ "$INSTALL_OPTION" = "torch" ]; then \
        pip install --no-cache-dir .[torch] && \
        crawl4ai-download-models; \
    elif [ "$INSTALL_OPTION" = "transformer" ]; then \
        pip install --no-cache-dir .[transformer] && \
        crawl4ai-download-models; \
    else \
        pip install --no-cache-dir .; \
    fi

# Set environment variables
ENV CHROME_BIN=/usr/bin/google-chrome \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PYTHONUNBUFFERED=1

# Make port 80 available to the world outside this container
EXPOSE 80

# Install mkdocs
RUN pip install mkdocs mkdocs-terminal

# Call mkdocs to build the documentation
RUN mkdocs build

# Run uvicorn
CMD ["sh", "-c", "Xvfb :99 -screen 0 1920x1080x16 & uvicorn main:app --host 0.0.0.0 --port 80 --workers 4"]
