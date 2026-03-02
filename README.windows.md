# Windows Setup Guide

This guide walks Windows users through setting up a full Linux development environment using WSL (Windows Subsystem for Linux), Rancher Desktop for Docker, and all the tooling this project requires.

All development work (cloning the repo, running services, installing tools) happens **inside WSL**, not on the Windows side. Windows is used only for running VSCode and Rancher Desktop.

## Prerequisites

- Windows 10 version 2004+ or Windows 11
- Administrator access for initial setup
- At least 8 GB RAM (16 GB recommended)

---

## Step 1: Install WSL

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

This installs WSL 2 with Ubuntu as the default distribution. Restart your machine when prompted.

After restart, the Ubuntu terminal will open and ask you to create a Linux username and password. Choose something you will remember -- this is your Linux user, not your Windows account.

### Verify WSL is working

Open a new PowerShell window:

```powershell
wsl --list --verbose
```

You should see Ubuntu listed with VERSION 2.

### Useful WSL commands

```powershell
wsl --shutdown            # Restart WSL if something goes wrong
wsl --update              # Update the WSL kernel
wsl -d Ubuntu             # Open a specific distribution
```

---

## Step 2: Install Rancher Desktop

Rancher Desktop provides a Docker-compatible container runtime on Windows without requiring Docker Desktop (which has commercial licensing restrictions for larger organizations).

1. Download Rancher Desktop from https://rancherdesktop.io/
2. Run the installer
3. During setup, choose these options:
   - Container Engine: **dockerd (moby)** (not containerd -- this gives you Docker CLI compatibility)
   - Enable Kubernetes: optional, not needed for this project
   - Configure PATH: Yes

4. After installation, open Rancher Desktop and wait for it to finish initializing

### Configure WSL integration

Rancher Desktop automatically integrates with WSL 2. To verify:

1. Open Rancher Desktop -> Preferences -> WSL
2. Ensure your Ubuntu distribution is listed and enabled
3. Apply changes if needed

### Verify Docker works from WSL

Open your WSL Ubuntu terminal:

```bash
docker version
docker compose version
```

Both commands should return version information. If `docker` is not found, restart your WSL terminal or run `wsl --shutdown` from PowerShell and reopen.

---

## Step 3: Install VSCode with WSL Extension

### Install VSCode on Windows

Download and install from https://code.visualstudio.com/

### Install the WSL extension

1. Open VSCode
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "WSL" (publisher: Microsoft, extension ID: `ms-vscode-remote.remote-wsl`)
4. Click Install

### Connect VSCode to WSL

There are two ways to open a project inside WSL:

**Option A -- From the WSL terminal:**

```bash
# Navigate to your project inside WSL
cd ~/projects/sample_project_demo

# Open VSCode connected to WSL
code .
```

This will install the VSCode server inside WSL on first run and open a remote window.

**Option B -- From VSCode:**

1. Press Ctrl+Shift+P to open the command palette
2. Type "WSL: Connect to WSL"
3. Select your Ubuntu distribution
4. Use File -> Open Folder to navigate to your project

### How to tell you are connected

When VSCode is connected to WSL, the bottom-left corner shows:

```
WSL: Ubuntu
```

All terminal windows inside VSCode will be Linux terminals, not PowerShell.

### Recommended extensions (install on the WSL side)

After connecting to WSL, install these extensions. VSCode will prompt you to install them "in WSL" -- always choose the WSL side:

- Python (ms-python.python)
- Pylance (ms-python.vscode-pylance)
- ESLint (dbaeumer.vscode-eslint)

---

## Step 4: Install Docker CLI in WSL

If Rancher Desktop's WSL integration is working (Step 2), Docker CLI is already available. Verify:

```bash
docker version
```

If Docker is **not** available despite Rancher Desktop being configured, install the CLI tools manually inside WSL:

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CLI and compose plugin (not the daemon -- Rancher Desktop provides that)
sudo apt-get update
sudo apt-get install -y docker-ce-cli docker-compose-plugin
```

### Point Docker CLI at Rancher Desktop's socket

If the CLI is installed manually but cannot connect to the daemon, configure the socket:

```bash
export DOCKER_HOST=unix://$HOME/.rd/docker.sock
```

Add that line to your `~/.bashrc` or `~/.zshrc` to make it persistent.

---

## Step 5: Install Python, uv, and pyenv

### Install pyenv

```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

# Install pyenv
curl https://pyenv.run | bash
```

Add the following to your `~/.bashrc` (the installer will remind you):

```bash
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

Restart your shell, then install Python:

```bash
pyenv install 3.12
pyenv global 3.12
python --version   # Should show 3.12.x
```

### Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Restart your shell and verify:

```bash
uv --version
```

---

## Step 6: Install Node.js via nvm

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash

# Restart your shell, then install Node
nvm install 18
nvm use 18

# Verify
node --version    # Should show v18.x.x
npm --version
```

---

## Step 7: Clone and Run the Project

All of this happens inside WSL:

```bash
# Create a projects directory (keep code inside the WSL filesystem for performance)
mkdir -p ~/projects
cd ~/projects

# Clone the repo
git clone <repository-url> sample_project_demo
cd sample_project_demo

# Run with Docker Compose (all services in containers)
./setup.sh

# Or run locally (services on host, only Jaeger in Docker)
./setup.sh --local
```

### Important: File system performance

Keep your project files inside the WSL filesystem (`~/projects/...`), **not** on the Windows filesystem (`/mnt/c/...`). Accessing files across the boundary is significantly slower and can cause issues with file watchers and build tools.

---

## Troubleshooting

### "docker: command not found" in WSL

1. Make sure Rancher Desktop is running
2. Check Rancher Desktop -> Preferences -> WSL and ensure Ubuntu is enabled
3. Run `wsl --shutdown` from PowerShell and reopen WSL

### "Permission denied" when running docker

Rancher Desktop usually handles this. If not:

```bash
sudo usermod -aG docker $USER
```

Log out and back in to WSL for the group change to take effect.

### VSCode does not show "WSL: Ubuntu" in the corner

- Ensure the WSL extension is installed
- Try Ctrl+Shift+P -> "WSL: Connect to WSL"
- If that does not appear, restart VSCode

### Shell scripts fail with "bad interpreter" or carriage return errors

The `.gitattributes` in this repo enforces LF line endings. If you cloned on the Windows side and moved files, line endings may be wrong:

```bash
# Fix line endings inside WSL
git config core.autocrlf input
git rm --cached -r .
git reset --hard
```

### Python/Node commands not found after install

Make sure you restarted your shell (close the terminal and open a new one). The installers modify `~/.bashrc`, which is only read on shell startup.

### Slow file access or builds

You are likely running from `/mnt/c/...`. Move the project to the WSL filesystem:

```bash
cp -r /mnt/c/Users/YourName/projects/sample_project_demo ~/projects/
cd ~/projects/sample_project_demo
```

---

## Summary: What Goes Where

| Component | Runs on | Notes |
|-----------|---------|-------|
| WSL (Ubuntu) | Windows (as a lightweight VM) | All CLI tools and development happen here |
| Rancher Desktop | Windows | Provides the Docker daemon; integrates with WSL |
| VSCode | Windows | Connects to WSL via the WSL extension |
| Docker CLI | Inside WSL | Talks to Rancher Desktop's Docker daemon |
| Python, uv, pyenv | Inside WSL | Installed and used entirely within Linux |
| Node.js, nvm, npm | Inside WSL | Installed and used entirely within Linux |
| Project files | WSL filesystem (`~/projects/`) | Do NOT use `/mnt/c/` for performance reasons |
