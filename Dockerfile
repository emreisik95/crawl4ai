FROM python:3.11-slim-bookworm

# Set the working directory in the container
WORKDIR /usr/src/app

# Define build arguments
ARG INSTALL_OPTION=default

# Install build dependencies and Chromium
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
    software-properties-common \
    chromium-driver \
    chromium && \
    rm -rf /var/lib/apt/lists/*    

# Copy the application code
COPY . .

# Install Crawl4AI using the local setup.py with the specified option
# and download models only for torch, transformer, or all options
RUN if [ "$INSTALL_OPTION" = "all" ]; then \
        pip install --no-cache-dir .[all] numpy && \
        crawl4ai-download-models; \
    elif [ "$INSTALL_OPTION" = "torch" ]; then \
        pip install --no-cache-dir .[torch] numpy && \
        crawl4ai-download-models; \
    elif [ "$INSTALL_OPTION" = "transformer" ]; then \
        pip install --no-cache-dir .[transformer] numpy && \
        crawl4ai-download-models; \
    else \
        pip install --no-cache-dir . numpy; \
    fi

# Set environment to use Chromium properly
ENV CHROME_BIN=/usr/bin/chromium \
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
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
