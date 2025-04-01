from fastapi import FastAPI
import requests

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from EKS!"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/git/status")
def github_status():
    try:
        response = requests.get("https://www.githubstatus.com/api/v2/status.json", timeout=5)
        data = response.json()
        return {
            "status": data.get("status", {}).get("description", "unknown"),
            "indicator": data.get("status", {}).get("indicator", "unknown")
        }
    except Exception as e:
        return {"error": str(e)}