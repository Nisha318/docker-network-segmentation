FROM python:3.12-slim

WORKDIR /app

RUN adduser --disabled-password --no-create-home appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

USER appuser

EXPOSE 5000
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0"]  