# Something Framework

A modular, bash-based monitoring framework designed to send real-time alerts and status updates to Telegram.

## Features

- **Modular Architecture**: Easy to extend with new monitoring plugins in the `modules/` directory.
- **Interactive CLI**: Comprehensive management via the `something` command.
- **Automated Setup**: Interactive configuration for Telegram bots and module-specific variables.
- **Zero Credentials in Git**: Template-based configuration system with `.gitignore` protection.
- **Support for Multiple Monitors**:
  - **System**: Monitor CPU, Memory, and Disk usage.
  - **PM2**: Monitor Node.js process status and restarts.
  - **Redis**: Monitor Redis server availability and performance.

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url> something
   cd something
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

3. Follow the setup prompts:
   ```bash
   bin/something setup
   ```

## Usage

```bash
# Start the monitoring engine
bin/something start

# Stop the engine
bin/something stop

# Check current status
bin/something status

# Reconfigure the framework
bin/something setup
```

## Creating New Modules

Simply create a new script in the `modules/` directory following the `module_setup` and `module_check` patterns. Use `modules/redis.sh` as a template.

---
*Built with simplicity and modularity in mind.*
