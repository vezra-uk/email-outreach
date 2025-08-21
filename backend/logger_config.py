import logging
import logging.handlers
import structlog
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


class ExtraFormatter(logging.Formatter):
    """Custom formatter that includes extra fields in log output."""
    
    def format(self, record):
        # Get the base formatted message
        msg = super().format(record)
        
        # Get extra fields (anything not in the standard record attributes)
        standard_attrs = {
            'name', 'msg', 'args', 'levelname', 'levelno', 'pathname', 'filename',
            'module', 'lineno', 'funcName', 'created', 'msecs', 'relativeCreated',
            'thread', 'threadName', 'processName', 'process', 'getMessage', 'exc_info',
            'exc_text', 'stack_info', 'asctime'
        }
        
        extras = {}
        for key, value in record.__dict__.items():
            if key not in standard_attrs:
                extras[key] = value
        
        # Append extras to the message if any exist
        if extras:
            extra_str = " | ".join([f"{k}={v}" for k, v in extras.items()])
            msg = f"{msg} | EXTRAS: {extra_str}"
        
        return msg

def setup_logging(log_level: str = "INFO", log_file: str = "app.log") -> None:
    """Configure comprehensive logging for the application."""
    
    # Create logs directory if it doesn't exist
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # Configure standard library logging
    log_level_obj = getattr(logging, log_level.upper())
    
    # Create formatters
    console_formatter = ExtraFormatter(
        '%(asctime)s | %(levelname)-8s | %(name)s:%(lineno)d | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    file_formatter = ExtraFormatter(
        '%(asctime)s | %(levelname)-8s | %(name)s:%(lineno)d | %(funcName)s | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Root logger configuration
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level_obj)
    
    # Clear existing handlers
    root_logger.handlers.clear()
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level_obj)
    console_handler.setFormatter(console_formatter)
    root_logger.addHandler(console_handler)
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        log_dir / log_file,
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding='utf-8'
    )
    file_handler.setLevel(log_level_obj)
    file_handler.setFormatter(file_formatter)
    root_logger.addHandler(file_handler)
    
    # Error-specific file handler
    error_handler = logging.handlers.RotatingFileHandler(
        log_dir / "errors.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=10,
        encoding='utf-8'
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(file_formatter)
    root_logger.addHandler(error_handler)
    
    # Configure structlog for structured logging
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.TimeStamper(fmt="ISO"),
            structlog.dev.ConsoleRenderer() if log_level.upper() == "DEBUG" else structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(log_level_obj),
        logger_factory=structlog.WriteLoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Set specific loggers to appropriate levels
    logging.getLogger("uvicorn.access").setLevel(logging.INFO)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    
    # Log startup message
    logger = logging.getLogger(__name__)
    logger.info(f"Logging configured with level: {log_level}")

def get_logger(name: str) -> logging.Logger:
    """Get a logger instance with the given name."""
    return logging.getLogger(name)

def log_function_call(func_name: str, args: Dict[str, Any] = None, user_id: str = None):
    """Decorator to log function calls with parameters."""
    def decorator(func):
        def wrapper(*args_inner, **kwargs):
            logger = get_logger(func.__module__)
            log_data = {
                "function": func_name,
                "user_id": user_id,
                "timestamp": datetime.utcnow().isoformat(),
            }
            if args:
                log_data.update(args)
            
            logger.info(f"Function call: {func_name}", extra=log_data)
            
            try:
                result = func(*args_inner, **kwargs)
                logger.info(f"Function completed: {func_name}", extra={**log_data, "status": "success"})
                return result
            except Exception as e:
                logger.error(f"Function failed: {func_name}", extra={
                    **log_data, 
                    "status": "error",
                    "error": str(e),
                    "error_type": type(e).__name__
                }, exc_info=True)
                raise
        return wrapper
    return decorator