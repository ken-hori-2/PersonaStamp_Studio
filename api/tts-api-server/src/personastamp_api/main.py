"""
Main entry point for the API server
Used for Render deployment and local development
"""

from core.api_server import app

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)





