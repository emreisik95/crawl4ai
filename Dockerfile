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

# Ensure transformers is installed if required
RUN if [ "$INSTALL_OPTION" = "all" ] || [ "$INSTALL_OPTION" = "transformer" ]; then \
        pip install --no-cache-dir transformers; \
    fi

# Install Crawl4AI using the local setup.py with the specified option
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

# Install Chromium for ARM64 architecture
RUN apt-get update && \
    apt-get install -y chromium

# Install Firefox and Geckodriver
RUN apt-get update && \
    apt-get install -y firefox-esr wget && \
    wget https://github.com/mozilla/geckodriver/releases/latest/download/geckodriver-v0.34.0-linux64.tar.gz && \
    tar -xzf geckodriver-v0.34.0-linux64.tar.gz && \
    mv geckodriver /usr/local/bin/ && \
    chmod +x /usr/local/bin/geckodriver && \
    rm geckodriver-v0.34.0-linux64.tar.gz
    
# Selenium'u Geckodriver ile çalışacak şekilde yapılandırın
ENV SELENIUM_BROWSER=firefox

# Set environment to use Chromium and ChromeDriver properly
ENV CHROME_BIN=/usr/bin/chromium \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PYTHONUNBUFFERED=1

# Ensure the PATH environment variable includes the location of the installed packages
ENV PATH=/opt/conda/bin:$PATH

# Make port 80 available to the world outside this container
EXPOSE 80

# Install mkdocs
RUN pip install mkdocs mkdocs-terminal

# Call mkdocs to build the documentation
RUN mkdocs build

# Run uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
