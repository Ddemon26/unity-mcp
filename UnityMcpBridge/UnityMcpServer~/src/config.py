"""
Configuration settings for the MCP for Unity Server.
This file contains all configurable parameters for the server.
"""

import os
from dataclasses import dataclass


def get_env_bool(key: str, default: bool) -> bool:
    """Get boolean value from environment variable."""
    value = os.getenv(key, "").lower()
    if value in ("true", "1", "yes", "on"):
        return True
    elif value in ("false", "0", "no", "off"):
        return False
    return default


def get_env_float(key: str, default: float) -> float:
    """Get float value from environment variable."""
    try:
        return float(os.getenv(key, str(default)))
    except (ValueError, TypeError):
        return default


def get_env_int(key: str, default: int) -> int:
    """Get integer value from environment variable."""
    try:
        return int(os.getenv(key, str(default)))
    except (ValueError, TypeError):
        return default


@dataclass
class ServerConfig:
    """Main configuration class for the MCP server."""

    # Network settings
    unity_host: str = os.getenv("UNITY_HOST", "localhost")
    unity_port: int = get_env_int("UNITY_PORT", 6400)
    mcp_port: int = get_env_int("MCP_PORT", 6500)

    # Connection settings
    # short initial timeout; retries use shorter timeouts
    connection_timeout: float = get_env_float("CONNECTION_TIMEOUT", 1.0)
    buffer_size: int = get_env_int("BUFFER_SIZE", 16 * 1024 * 1024)  # 16MB buffer
    # Framed receive behavior
    # max seconds to wait while consuming heartbeats only
    framed_receive_timeout: float = get_env_float("FRAMED_RECEIVE_TIMEOUT", 2.0)
    # cap heartbeat frames consumed before giving up
    max_heartbeat_frames: int = get_env_int("MAX_HEARTBEAT_FRAMES", 16)

    # Logging settings
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
    log_format: str = os.getenv("LOG_FORMAT", "%(asctime)s - %(name)s - %(levelname)s - %(message)s")

    # Server settings
    max_retries: int = get_env_int("MAX_RETRIES", 10)
    retry_delay: float = get_env_float("RETRY_DELAY", 0.25)
    # Backoff hint returned to clients when Unity is reloading (milliseconds)
    reload_retry_ms: int = get_env_int("RELOAD_RETRY_MS", 250)
    # Number of polite retries when Unity reports reloading
    # 40 × 250ms ≈ 10s default window
    reload_max_retries: int = get_env_int("RELOAD_MAX_RETRIES", 40)

    # Telemetry settings
    telemetry_enabled: bool = get_env_bool("TELEMETRY_ENABLED", True) and not get_env_bool("DISABLE_TELEMETRY", False)
    # Align with telemetry.py default Cloud Run endpoint
    telemetry_endpoint: str = os.getenv("TELEMETRY_ENDPOINT", "https://api-prod.coplay.dev/telemetry/events")


# Create a global config instance
config = ServerConfig()
