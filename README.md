<h1 align="center">
  🎵 SinusBot Multi-Instance Installer
</h1>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/platform-linux%20%7C%20debian%20%7C%20ubuntu-brightgreen?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/bash-%3E%3D4.0-lightgrey?style=flat-square" alt="Bash">
</p>

<p align="center">
  <b>One command – full SinusBot environment. Repeatable, isolated, production‑ready.</b><br>
  Deploy and manage multiple SinusBot instances on Debian/Ubuntu with zero manual configuration.
</p>

---

## ✨ Features

- ⚡ **Multi‑instance ready** – run dozens of completely independent bots on one server.
- 🔧 **Full‑stack automation** – optional system dependency installation, TS3 client extraction, plugin setup, and more.
- 🧹 **Clean removal** – one option stops, disables, deletes the user and purges all files.
- 🎯 **Smart port selection** – automatically finds the first free port starting from `8089`.
- 🛡️ **Firewall aware** – opens the chosen port in `ufw` if it’s active.
- ⚙️ **systemd service** – each instance is a native service with resource limits and automatic restart.
- 🔐 **Password display** – grabs the generated admin password from the journal and prints it after installation.
- 🌐 **Network safety** – blocks TeamSpeak blacklist/update servers via `/etc/hosts`.
- 📦 **Script injection** – copies your custom scripts from a local folder into the new instance.

---

## 📦 Prerequisites

| Component          | Details                                                                 |
| ------------------ | ----------------------------------------------------------------------- |
| **OS**             | Debian 10+ / Ubuntu 18.04+ (apt‑based)                                  |
| **Privileges**     | Must be run as **root**                                                 |
| **Tools**          | `tar`, `curl`, `useradd`, `systemctl` (already present on most systems) |
| **Required files** | Both files must be in the same directory as the script:                 |
|                    | • `sinusbot.current.tar.bz2`                                            |
|                    | • `TeamSpeak3-Client-linux_amd64-3.5.6.run`                             |

> Download SinusBot from [sinusbot.com](https://www.sinusbot.com/) and the TS3 client from [teamspeak.com](https://www.teamspeak.com/).

---

## 🚀 Quick Start

### 1️⃣ Prepare the workspace

```bash
mkdir -p ~/sinusbot-installer
cd ~/sinusbot-installer

# Place both required files and the script here
ls -1
# sinusbot.current.tar.bz2
# TeamSpeak3-Client-linux_amd64-3.5.6.run
# install.sh                  ← the script from this repository
```
