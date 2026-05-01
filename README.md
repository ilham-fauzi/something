# 🛸 Something Framework

> A modular, high-security monitoring framework for Telegram.

**Something** is a production-ready, bash-based monitoring system designed for developers who need robust alerts without the overhead of heavy monitoring suites. It features a unique **Encrypted Vault** system and a **Telegram Gatekeeper** for secure remote management.

---

## ✨ Key Features

-   🛡️ **Encrypted Vault**: All sensitive credentials (API tokens, passwords) are stored in an AES-256 encrypted vault.
-   💂 **Telegram Gatekeeper**: Remote boot-unlocking. If your server reboots, the system stays locked until you send the Master Key via Telegram.
-   🧩 **Plug-and-Play Modules**: Extensible architecture. Create monitors for anything (Redis, PM2, Docker, Databases) in seconds.
-   ⚡ **Lightweight & Fast**: Pure Bash logic with minimal dependencies.
-   🕵️ **Identity Verification**: Multi-layered security ensures only authorized Telegram IDs can interact with your system.

---

## 🔐 Security Architecture

### The Vault
Sensitive data is never stored in plaintext. When you run `something setup`, the framework generates a `something.conf.enc` file. 
-   **Security**: Plaintext configs are automatically deleted after encryption.
-   **Safety**: Even if your server is compromised, the hacker cannot read your Telegram tokens or database credentials without the **Master Key**.

### The Gatekeeper
When the server starts, a background process called **Gatekeeper** activates.
1.  It polls Telegram and notifies authorized **Gatekeeper IDs** that the system is locked.
2.  It waits for the **Master Key** to be sent via a private message.
3.  Upon receiving the correct key, it unlocks the vault, starts the monitoring engine, and securely clears the key from memory.

> [!IMPORTANT]
> **Identity Binding**: The Gatekeeper verifies the sender's Chat ID against the encrypted `G_SENDER_ID` stored inside the vault. Even if someone guesses your Master Key, they cannot unlock the system unless they are using your specific Telegram account.

---

## 🛠 Technical Requirements

-   **OS**: Linux / macOS
-   **Shell**: Bash 4.0+
-   **Utilities**: `curl`, `jq`, `openssl` (for encryption)

---

## 📥 Installation

1.  **Clone the Repo**:
    ```bash
    git clone <repository-url> something
    cd something
    ```

2.  **Run Installer**:
    ```bash
    ./install.sh
    ```
    *This will set up permissions and prepare the directory structure.*

---

## 🕹 Command Reference

The `something` CLI is your control center.

### ⚙️ Configuration
| Command | Description |
| :--- | :--- |
| `something setup` | Start the interactive setup wizard. |
| `something setup -a auto` | Fast-track: Auto-detect Telegram Chat ID. |
| `something setup -a <chatId>` | Fast-track: Manually provide Telegram Chat ID. |
| `something vault` | Manually lock/unlock or re-encrypt your configuration. |

### 🚀 Operations
| Command | Description |
| :--- | :--- |
| `something start [module]` | Start the engine (or a specific module). |
| `something stop [module]` | Stop all monitoring (or a specific module). |
| `something status` | View health and status of all active monitors. |
| `something logs` | Tail the system and module logs. |

### 🔨 Development
| Command | Description |
| :--- | :--- |
| `something create -m <name>` | Generate a boilerplate for a new monitoring module. |

---

## 🔌 Developer Guide: Creating Modules

Modules are simple bash scripts located in `modules/`.

1.  **Generate a new module**:
    ```bash
    bin/something create -m my_service
    ```
2.  **Implement your logic**:
    -   `module_setup`: Define variables the user needs to provide.
    -   `module_check`: The core logic that runs every cycle. Use `send_msg "Alert text"` for notifications.

Example `modules/my_service.sh`:
```bash
module_check() {
    status=$(check_service_health)
    if [ "$status" != "OK" ]; then
        send_msg "🚨 My Service is DOWN on $(hostname)!"
    fi
}
```

---

## 📂 Project Structure

```text
something/
├── bin/
│   ├── something           # Main CLI Entry Point
│   └── something-gatekeeper # Boot Unlocker
├── config/
│   ├── boot.conf           # Public bridge for Gatekeeper (Safe)
│   └── something.conf.enc  # The Encrypted Vault (Secret)
├── lib/
│   ├── engine.sh           # Core execution logic
│   ├── telegram.sh         # Telegram API wrappers
│   └── utils.sh            # Encryption & Helper functions
├── modules/                # Monitoring plugins
└── logs/                   # System & Module logs
```

---
*Built with ❤️ for secure, modular monitoring.*
