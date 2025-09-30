#!/usr/bin/env python3
"""
Test script to validate Docker configuration and setup.
This script can be run inside a Docker container to verify the MCP server setup.
"""

import os
import sys
import json
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_environment_variables():
    """Test that environment variables are properly set."""
    logger.info("Testing environment variables...")
    
    expected_vars = {
        'UNITY_HOST': 'host.docker.internal',
        'UNITY_PORT': '6400',
        'MCP_PORT': '6500',
        'LOG_LEVEL': 'INFO'
    }
    
    errors = []
    for var, default in expected_vars.items():
        value = os.getenv(var, default)
        logger.info(f"{var} = {value}")
        
        if var in ['UNITY_PORT', 'MCP_PORT']:
            try:
                port = int(value)
                if not (1024 <= port <= 65535):
                    errors.append(f"{var} ({port}) is not in valid port range")
            except ValueError:
                errors.append(f"{var} ({value}) is not a valid integer")
    
    return errors

def test_python_dependencies():
    """Test that required Python packages are installed."""
    logger.info("Testing Python dependencies...")
    
    required_packages = ['mcp', 'httpx']
    errors = []
    
    for package in required_packages:
        try:
            __import__(package)
            logger.info(f"✓ {package} is installed")
        except ImportError:
            errors.append(f"Missing required package: {package}")
            logger.error(f"✗ {package} is not installed")
    
    return errors

def test_file_structure():
    """Test that required files are present."""
    logger.info("Testing file structure...")
    
    required_files = [
        'config.py',
        'server.py',
        'unity_connection.py',
        'pyproject.toml',
        'tools/__init__.py'
    ]
    
    errors = []
    for file_path in required_files:
        path = Path(file_path)
        if path.exists():
            logger.info(f"✓ {file_path} exists")
        else:
            errors.append(f"Missing required file: {file_path}")
            logger.error(f"✗ {file_path} not found")
    
    return errors

def test_configuration_loading():
    """Test that configuration can be loaded properly."""
    logger.info("Testing configuration loading...")
    
    errors = []
    try:
        # Add current directory to Python path
        sys.path.insert(0, '/app')
        
        import config
        cfg = config.config
        
        # Test basic configuration attributes
        required_attrs = [
            'unity_host', 'unity_port', 'mcp_port',
            'log_level', 'connection_timeout', 'max_retries'
        ]
        
        for attr in required_attrs:
            if hasattr(cfg, attr):
                value = getattr(cfg, attr)
                logger.info(f"✓ config.{attr} = {value}")
            else:
                errors.append(f"Missing configuration attribute: {attr}")
                logger.error(f"✗ config.{attr} not found")
                
    except Exception as e:
        errors.append(f"Failed to load configuration: {str(e)}")
        logger.error(f"✗ Configuration loading failed: {e}")
    
    return errors

def test_ports_accessibility():
    """Test that ports can be bound to (basic network test)."""
    logger.info("Testing port accessibility...")
    
    import socket
    errors = []
    
    # Test MCP port
    mcp_port = int(os.getenv('MCP_PORT', '6500'))
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.bind(('0.0.0.0', mcp_port))
        sock.close()
        logger.info(f"✓ Port {mcp_port} is available")
    except Exception as e:
        errors.append(f"Cannot bind to MCP port {mcp_port}: {str(e)}")
        logger.error(f"✗ Port {mcp_port} test failed: {e}")
    
    return errors

def generate_test_report(all_errors):
    """Generate a test report."""
    if not all_errors:
        logger.info("🎉 All tests passed! Docker setup is valid.")
        return True
    else:
        logger.error("❌ Some tests failed:")
        for error in all_errors:
            logger.error(f"  - {error}")
        return False

def main():
    """Run all tests and generate report."""
    logger.info("Starting Unity MCP Docker validation tests...")
    logger.info("=" * 50)
    
    all_errors = []
    
    # Run all test functions
    test_functions = [
        test_environment_variables,
        test_python_dependencies,
        test_file_structure,
        test_configuration_loading,
        test_ports_accessibility
    ]
    
    for test_func in test_functions:
        try:
            errors = test_func()
            all_errors.extend(errors)
        except Exception as e:
            all_errors.append(f"Test {test_func.__name__} crashed: {str(e)}")
            logger.error(f"Test {test_func.__name__} crashed: {e}")
        
        logger.info("-" * 30)
    
    # Generate final report
    success = generate_test_report(all_errors)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()