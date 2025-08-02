# BizSync Installation Guide

## Prerequisites

- Python 3.8+
- pip
- Git

## Universal Installation Steps

1. Clone the repository:
```bash
git clone https://github.com/siva-sub/bizsync.git
cd bizsync
```

## Platform-Specific Installation

### Linux

1. Install dependencies:
```bash
sudo apt-get update
sudo apt-get install python3-pip
pip3 install -r requirements.txt
```

2. Run the application:
```bash
./build.sh
./dist/bizsync-linux-1.0.0
```

### macOS

1. Install Homebrew (if not already installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install Python and dependencies:
```bash
brew install python
pip3 install -r requirements.txt
```

3. Run the application:
```bash
./build.sh
./dist/bizsync-macos-1.0.0
```

### Windows

1. Install Python from [python.org](https://www.python.org/downloads/windows/)
2. Open Command Prompt:
```cmd
pip install -r requirements.txt
build.bat
dist\bizsync-windows-1.0.0.exe
```

## Configuration

Copy `config.template.yml` to `config.yml` and customize settings.

## Troubleshooting

- Ensure all dependencies are installed
- Check Python version compatibility
- Verify network and firewall settings

## Author

Sivasubramanian Ramanthan
- Website: sivasub.com
- Contact: hello@sivasub.com