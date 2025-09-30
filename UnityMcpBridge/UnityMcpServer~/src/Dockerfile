FROM python:3.12-slim as base

# Install required system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager with fallback
RUN pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org uv || \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.cargo/bin/uv /usr/local/bin/

# Set working directory
WORKDIR /app

# Development stage
FROM base as development

# Copy all files for development
COPY . /app/

# Install dependencies including dev dependencies
RUN uv pip install --system -e ".[dev]" || uv pip install --system -e .

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose ports
EXPOSE 6500 6400

# Development command with auto-reload
CMD ["uv", "run", "--reload", "server.py"]

# Production stage
FROM base as production

# Copy only necessary files for production
COPY pyproject.toml uv.lock* ./
COPY *.py ./
COPY tools/ ./tools/

# Install only production dependencies
RUN uv pip install --system -e . --no-dev

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash --uid 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose the default MCP port
EXPOSE 6500

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import socket; s=socket.socket(); s.settimeout(5); s.connect(('localhost', 6500)); s.close()" || exit 1

# Production command
CMD ["uv", "run", "server.py"]

# Default to production
FROM production
