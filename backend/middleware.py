import time
import uuid
from fastapi import Request, Response
from fastapi.responses import JSONResponse
import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from logger_config import get_logger

logger = get_logger(__name__)

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log all HTTP requests and responses."""
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
    
    async def dispatch(self, request: Request, call_next):
        # Generate request ID for tracing
        request_id = str(uuid.uuid4())[:8]
        
        # Extract client information
        client_ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "")
        
        # Log request start
        start_time = time.time()
        logger.info("Request started", extra={
            "request_id": request_id,
            "method": request.method,
            "path": str(request.url.path),
            "query_params": str(request.query_params),
            "client_ip": client_ip,
            "user_agent": user_agent[:200] if user_agent else "",
            "content_type": request.headers.get("content-type", ""),
            "content_length": request.headers.get("content-length", "0")
        })
        
        # Add request ID to state for use in endpoints
        request.state.request_id = request_id
        
        try:
            # Process request
            response = await call_next(request)
            
            # Calculate processing time
            process_time = time.time() - start_time
            
            # Log response
            logger.info("Request completed", extra={
                "request_id": request_id,
                "method": request.method,
                "path": str(request.url.path),
                "status_code": response.status_code,
                "process_time_ms": round(process_time * 1000, 2),
                "response_size": response.headers.get("content-length", "unknown")
            })
            
            # Add request ID to response headers for debugging
            response.headers["X-Request-ID"] = request_id
            
            return response
            
        except Exception as e:
            # Calculate processing time even for errors
            process_time = time.time() - start_time
            
            # Log error
            logger.error("Request failed", extra={
                "request_id": request_id,
                "method": request.method,
                "path": str(request.url.path),
                "process_time_ms": round(process_time * 1000, 2),
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            
            # Return generic error response
            return JSONResponse(
                status_code=500,
                content={"error": "Internal server error", "request_id": request_id},
                headers={"X-Request-ID": request_id}
            )

class DatabaseLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log database operations."""
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
    
    async def dispatch(self, request: Request, call_next):
        # Track database operations for this request
        db_start_time = time.time()
        
        response = await call_next(request)
        
        # Log database performance metrics if available
        db_time = time.time() - db_start_time
        
        # Only log if DB time is significant (>100ms) or if it's an API endpoint
        if db_time > 0.1 or str(request.url.path).startswith('/api/'):
            logger.debug("Database operations completed", extra={
                "request_id": getattr(request.state, 'request_id', 'unknown'),
                "path": str(request.url.path),
                "db_time_ms": round(db_time * 1000, 2)
            })
        
        return response