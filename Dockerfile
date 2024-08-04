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
    xvfb \
    ca-certificates \
    apt-transport-https \
    software-properties-common && \
    rm -rf /var/lib/apt/lists/*    

# Copy the application code
COPY . .

# Install Crawl4AI with optional dependencies and download models based on the INSTALL_OPTION
RUN case "$INSTALL_OPTION" in \
        "all") pip install --no-cache-dir .[all] && crawl4ai-download-models ;; \
        "torch") pip install --no-cache-dir .[torch] && crawl4ai-download-models ;; \
        "transformer") pip install --no-cache-dir .[transformer] && crawl4ai-download-models ;; \
        *) pip install --no-cache-dir . ;; \
    esac

# Install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list' && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Set environment to use Chrome properly
ENV CHROME_BIN=/usr/bin/google-chrome \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PYTHONUNBUFFERED=1

# Make port 80 available to the world outside this container
EXPOSE 80

# Install mkdocs and build documentation
RUN pip install mkdocs mkdocs-terminal && mkdocs build

# Run uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
