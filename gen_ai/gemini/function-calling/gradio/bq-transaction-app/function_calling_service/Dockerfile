FROM python:3.10-slim
ENV PYTHONUNBUFFERED True

RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r  requirements.txt

ENV APP_HOME /root
WORKDIR $APP_HOME
COPY /app $APP_HOME/app

EXPOSE 8080
CMD ["gunicorn", "--bind", ":8080", "--workers", "1", "--threads", "8", "--timeout", "0", "app.main:app"]