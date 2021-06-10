#!/bin/bash

set -e
set -v

if [[ "$1" == "-h" ]]; then
  echo "usage ./install_requirements.sh"
  exit
fi

sudo apt-get install -y python3-dev protobuf-compiler git unzip

# assuming pip is intalled, pyenv, pipenv etc. are set up.

pip install cython pillow lxml matplotlib opencv-python-headless pyyaml
pip install git+https://github.com/cocodataset/cocoapi#subdirectory=PythonAPI

echo "===== Installed Packages ====="
pip freeze
