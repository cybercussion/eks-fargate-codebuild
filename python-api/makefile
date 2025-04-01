.PHONY: run install dev test format

# Install dependencies from requirements.txt
install:
	pip install -r requirements.txt

# Run the FastAPI app (assumes app/main.py)
run:
	uvicorn app.main:app --reload

# Install dependencies and run the dev server
dev: install run

# Run tests (if you add pytest later)
test:
	pytest tests/

# Format code using black
format:
	black app