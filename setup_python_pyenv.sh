#!/bin/bash

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

python3 -m venv venv

./venv/bin/python3.9 -m pip install --upgrade pip

source venv/bin/activate

pip install -e .
