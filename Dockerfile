FROM python:3.10-slim-bookworm

WORKDIR /usr/src/app

ARG INSTALL_OPTION=default

# Install dependencies and Chromium/ChromiumDriver
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget xvfb unzip curl gnupg2 ca-certificates apt-transport-https software-properties-common \
    chromium chromium-driver

# Copy application code
COPY . .

# Optional installation of Transformers based on INSTALL_OPTION
RUN if [ "$INSTALL_OPTION" = "all" ] || [ "$INSTALL_OPTION" = "transformer" ]; then \
        pip install --no-cache-dir transformers; \
    fi

# Install Python dependencies and specific packages based on INSTALL_OPTION
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

# Environment variables for Chromium and Selenium
ENV CHROME_BIN=/usr/bin/chromium \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    PYTHONUNBUFFERED=1

# Expose port 80
EXPOSE 80

# Install MkDocs and build documentation
RUN pip install mkdocs mkdocs-terminal
RUN mkdocs build

# Command to run the application with Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80", "--workers", "4"]
