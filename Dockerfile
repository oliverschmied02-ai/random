FROM python:3.11-slim

WORKDIR /app

# System dependencies for pdfplumber / PyMuPDF
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmupdf-dev mupdf-tools \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create data directories
RUN mkdir -p data/files reports secrets

CMD ["python", "-m", "src", "schedule"]
