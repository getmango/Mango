# Mango

![banner](./public/img/banner-paddings.png)

Mango is a self-hosted manga server and reader. Its features include

- Multi-user support
- Supports both `.zip` and `.cbz` formats
- Automatically stores reading progress
- The web reader is responsive and works well on mobile, so there is no need for a mobile app
- All the static files are embedded in the binary, so the deployment process is easy and painless

## Installation

### Build from source

1. Make sure you have Crystal (0.32.0), Node and Yarn installed
2. Clone the repository
3. Run `make`
4. Move the compiled executable to your desired location and run it

## Usage

### CLI

```
Mango e-manga server/reader. Version 0.1.0

    -v, --version                    Show version
    -h, --help                       Show help
    -c PATH, --config=PATH           Path to the config file. Default is `~/.config/mango/config.yml`
```

### Config

The default config file location is `~/.config/mango/config.yml`. The config options and default values are given below

```yaml
---
port: 9000
library_path: ~/mango/library
db_path: ~/mango/mango.db
scan_interval_minutes: 5
log_level: info
```

### Initial Login

On the first run, Mango would log the default username and a randomly generated password to STDOUT. You are advised to immediately change the password.

## Screenshots

## Contributors

- [Alex Ling](https://github.com/your-github-user) - creator and maintainer
