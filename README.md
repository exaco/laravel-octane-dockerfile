<div align="center">
 <h1>Laravel Docker Setup</h1>
</div>
<div align="center">
 <a href="/LICENSE"><img alt="License" src="https://img.shields.io/github/license/exaco/laravel-octane-dockerfile"></a>
 <a href="https://github.com/exaco/laravel-octane-dockerfile/releases"><img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/exaco/laravel-octane-dockerfile"></a>
 <a href="https://github.com/exaco/laravel-octane-dockerfile/pulls"><img alt="GitHub closed pull requests" src="https://img.shields.io/github/issues-pr-closed/exaco/laravel-octane-dockerfile"></a>
 <br>
 <a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/roadrunner-test.yml/badge.svg"></a>
 <a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/swoole-test.yml/badge.svg"></a>
 <a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/frankenphp-test.yml/badge.svg"></a>
 <a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/docker-compose-test.yml/badge.svg"></a>
</div>
<br>

A finely tuned engine for deploying blazing-fast **Laravel Octane** applications. It combines the raw power of Octane with the streamlined efficiency of Docker and Docker Compose to create a **production-ready** environment that's ready to launch.

## Key Features

* **Octane-Optimized**: Built specifically to harness the performance gains of Laravel Octane, whether you prefer **FrankenPHP**, **Swoole** or **RoadRunner**.
* **Production-Ready Docker Compose:** A comprehensive Docker Compose file orchestrates a full stack, including:
  * **Traefik:** Intelligent reverse proxy for routing, load balancing, and secure access.
  * **PostgreSQL:** Robust and reliable database backend.
  * **Redis:** Lightning-fast caching for improved response times.
  * **Minio:** Scalable object storage for your application's assets.
  * **Typesense:** Powerful search engine to enhance user experience.
  * **pgAdmin & pghero:** Tools for database management and performance monitoring.
  * **Backup Service:** Automated backups to protect your valuable data.
  * **System Monitoring:** Glances and Netdata provide real-time insights into your infrastructure.
* **Security Hardened:** Includes best practices for security, such as user authentication for exposed services and restricted container privileges.
* **PHP Powerhouse:** Uses official PHP images (Debian or Alpine based) with pre-configured PHP runtime, JIT compiler, and OPcache for maximum performance.


## Laravel Container modes

Easily launch your container in different modes to handle specific tasks:


| Mode                  | `CONTAINER_MODE` value | Description
| --------------------- | ---------------- | ---------------- |
| HTTP Server (default) | `http` | Runs your Laravel Octane application.        |
| Horizon               | `horizon`        | Manages your queued jobs efficiently.        |
| Scheduler             | `scheduler`      | Executes scheduled tasks at defined intervals.        |
| Worker                | `worker`         | A dedicated worker for background processing.        |
| Reverb                | `reverb`         | Facilitates real-time communication with Laravel Echo.        |

## Prerequisites

- Docker installed on your system
- Docker Compose installed on your system
- Setup Laravel Octane, Laravel Horizon and Laravel Reverb

## Usage

### Building Docker image

1. Clone the repository:
```
git clone --depth 1 git@github.com:exaco/laravel-octane-dockerfile.git
```
2. Copy the contents of the cloned directory, including the following items, into your Laravel project powered by Octane:
   - `deployment` directory
   - `<your-octane-driver>.Dockerfile`
   - `.dockerignore` 
    
1. Change the directory to your Laravel project
2. Build your image:
```
docker build -t <image-name>:<tag> -f <your-octane-driver>.Dockerfile .
```

### Running Docker container

```bash
# HTTP mode
docker run -p <port>:8000 --rm <image-name>:<tag>

# Horizon mode
docker run -e CONTAINER_MODE=horizon --rm <image-name>:<tag>

# Scheduler mode
docker run -e CONTAINER_MODE=scheduler --rm <image-name>:<tag>

# Reverb mode
docker run -e CONTAINER_MODE=reverb --rm <image-name>:<tag>

# HTTP mode with Horizon
docker run -e WITH_HORIZON=true -p <port>:8000 --rm <image-name>:<tag>

# HTTP mode with Scheduler
docker run -e WITH_SCHEDULER=true -p <port>:8000 --rm <image-name>:<tag>

# HTTP mode with Scheduler and Horizon
docker run \
    -e WITH_SCHEDULER=true \
    -e WITH_HORIZON=true \
    -p <port>:8000 \
    --rm <image-name>:<tag>

# HTTP mode with Scheduler, Horizon and Reverb
docker run \
    -e WITH_SCHEDULER=true \
    -e WITH_HORIZON=true \
    -e WITH_REVERB=true \
    -p <port>:8000 \
    --rm <image-name>:<tag>

# Worker mode
docker run \
    -e CONTAINER_MODE=worker \
    -e WORKER_COMMAND="php /var/www/html/artisan foo:bar" \
    --rm <image-name>:<tag>

# Running a single command
docker run --rm <image-name>:<tag> php artisan about
```

### Docker Compose

To deploy your application stack with Docker Compose:
1. Copy the following items to your code base:
    - `docker-compose.production.yml`
    - `.env.production`
    - `Makefile`
2. Edit `.env.production` and populate it with the appropriate values for your production environment variables (e.g., database credentials, API keys).
3. Run the following command in your project root directory to prevent permission issues:
```bash
sudo mkdir -p storage/framework/{sessions,views,cache,testing} storage/logs && sudo chmod -R a+rw storage
```
4. Run the command `make up` to start the containers.

> [!NOTE]  
> The included `Makefile` offers a range of additional commands for managing your deployment, including options for rebuilding, stopping, and restarting services.

> [!CAUTION]
> Do not forget to edit `.env.production`!

## Configuration and Customization

* You can use the `APP_ENV` build argument to specify a different environment file.

### Recommended `Swoole` options in `octane.php`

```php
// config/octane.php

return [
    'swoole' => [
        'options' => [
            'http_compression' => true,
            'http_compression_level' => 6, // 1 - 9
            'compression_min_length' => 20,
            'package_max_length' => 2 * 1024 * 1024, // 2MB
            'upload_max_filesize' => 20 * 1024 * 1024 // 20MB
            'open_http2_protocol' => true,
            'document_root' => public_path(),
            'enable_static_handler' => true,
        ]
    ]
];
```

## Essential Notes

* Some configurations are highly opinionated, so please make sure they align with your needs.
* Laravel Octane logs request information only in the `local` environment.
* Be mindful of the contents of the `.dockerignore` file.

## ToDo
- [x] Add Docker Compose
- [x] Add support for PHP 8.4
- [x] Add support for worker mode
- [x] Build assets with Bun
- [x] Install more Caddy modules
- [x] Create standalone and self-executable app
- [x] Add support for Horizon
- [x] Add support for RoadRunner
- [x] Add support for FrankenPHP
- [x] Add support for Laravel Reverb
- [x] Add support for the full-stack apps (Front-end assets)
- [ ] Add support `testing` environment and CI
- [x] Add support for the Laravel scheduler
- [ ] Add support for Laravel Dusk
- [x] Support more PHP extensions
- [x] Add tests
- [x] Add Alpine-based images

## Contributing

Thank you for considering contributing! If you find an issue, or have a better way to do something, feel free to open an
issue, or a PR.

## Credits

- [SMortexa](https://github.com/smortexa)
- [All contributors](https://github.com/exaco/laravel-octane-dockerfile/graphs/contributors)

## License

This repository is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
