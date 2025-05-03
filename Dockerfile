FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04

WORKDIR /workspace

COPY . .

RUN pip install --upgrade pip  # optional: add any pip installs here

CMD ["bash", "startup.sh"]
