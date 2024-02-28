# Laravel Octane Dockerfile
<a href="/LICENSE"><img alt="License" src="https://img.shields.io/github/license/exaco/laravel-octane-dockerfile"></a>
<a href="https://github.com/exaco/laravel-octane-dockerfile/releases"><img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/exaco/laravel-octane-dockerfile"></a>
<a href="https://github.com/exaco/laravel-octane-dockerfile/pulls"><img alt="GitHub closed pull requests" src="https://img.shields.io/github/issues-pr-closed/exaco/laravel-octane-dockerfile"></a>
<a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/roadrunner-test.yml/badge.svg"></a>
<a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/swoole-test.yml/badge.svg"></a>
<a href="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/tests.yml"><img alt="GitHub Workflow Status" src="https://github.com/exaco/laravel-octane-dockerfile/actions/workflows/frankenphp-test.yml/badge.svg"></a>


Production-ready Dockerfiles for [Laravel Octane](https://github.com/laravel/octane)
powered web services and microservices.

The Docker configuration provides the following setup:

- PHP 8.2 and 8.3 official Debian-based images
- Preconfigured JIT compiler and OPcache

## Container modes

You can run the Docker container in different modes:

| Mode                  | `CONTAINER_MODE` | HTTP server         |
| --------------------- | ---------------- | ------------------- |
| HTTP Server (default) | `http`           | FrankenPHP / Swoole / RoadRunner |
| Horizon               | `horizon`        | -                   |
| Scheduler             | `scheduler`      | -                   |
| Worker                | `worker`         | -                   |

## Usage

### Building Docker image
1. Clone this repository:
```
git clone --depth 1 git@github.com:exaco/laravel-octane-dockerfile.git
```
2. Copy cloned directory content including `deployment` directory, `Dockerfile`, and `.dockerignore` into your Octane powered Laravel project
3. Change the directory to your Laravel project
4. Build your image:
```
docker build -t <image-name>:<tag> -f <your-octane-driver>.Dockerfile .
```
### Running Docker container

```bash
# HTTP mode
docker run -p <port>:80 --rm <image-name>:<tag>

# Horizon mode
docker run -e CONTAINER_MODE=horizon --rm <image-name>:<tag>

# Scheduler mode
docker run -e CONTAINER_MODE=scheduler --rm <image-name>:<tag>

# HTTP mode with Horizon
docker run -e WITH_HORIZON=true -p <port>:80 --rm <image-name>:<tag>

# HTTP mode with Scheduler
docker run -e WITH_SCHEDULER=true -p <port>:80 --rm <image-name>:<tag>

# HTTP mode with Scheduler and Horizon
docker run -e WITH_SCHEDULER=true -e WITH_HORIZON=true -p <port>:80 --rm <image-name>:<tag>

# Worker mode
docker run -e CONTAINER_MODE=worker -e WORKER_COMMAND="php /var/www/html/artisan foo:bar" --rm <image-name>:<tag>

# Running a single command
docker run --rm <image-name>:<tag> php artisan about
```

### Running Docker Composer

```YAML
version: '3.9'

services:
  # HTTP Server (Octane) only
  app:
    image: <image-name>:<tag>
    environment:
      - SERVER_NAME=http://mysite.com
      - CONTAINER_MODE=http
    env_file:
      -  .env
    ports:
      - <port>:80

  # HTTP Server (Octane) with Horizon and Scheduler
  app-horizon-scheduler:
    image: <image-name>:<tag>
    environment:
      - SERVER_NAME=http://mysite.com
      - CONTAINER_MODE=http
      - WITH_HORIZON=true
      - WITH_SCHEDULER=true
    env_file:
      -  .env
    ports:
      - <port>:80

  # Laravel Horizon only
  horizon:
    image: <image-name>:<tag>
    environment:
      - CONTAINER_MODE=horizon
    env_file:
      -  .env
    # DISABLE Healthcheck to keep container alive!
    healthcheck:
      disable: true

  # Laravel Scheduler only
  scheduler:
    image: <image-name>:<tag>
    environment:
      - CONTAINER_MODE=scheduler
    env_file:
      -  .env
    # DISABLE Healthcheck to keep container alive!
    healthcheck:
      disable: true

  # Laravel "worker" only
  worker:
    image: <image-name>:<tag>
    environment:
      - CONTAINER_MODE=worker
    env_file:
      -  .env
    # DISABLE Healthcheck to keep container alive!
    healthcheck:
      disable: true
```

## Configuration

### Recommended `Swoole` options in `octane.php`

```php
// config/octane.php

return [
    'swoole' => [
        'options' => [
            'http_compression' => true,
            'http_compression_level' => 6, // 1 - 9
            'compression_min_length' => 20,
            'package_max_length' => 20 * 1024 * 1024, // 20MB
            'open_http2_protocol' => true,
            'document_root' => public_path(),
            'enable_static_handler' => true,
        ]
    ]
];
```

## Utilities

Also, some useful Bash functions and aliases are added in `utilities.sh` that maybe help.

## Notes

- Laravel Octane logs request information only in the `local` environment.
- Please be aware of `.dockerignore` content

## ToDo
- [x] Add support for PHP 8.3
- [x] Add support for worker mode
- [ ] Build assets with Bun
- [ ] Create standalone and self-executable app
- [x] Add support for Horizon
- [x] Add support for RoadRunner
- [x] Add support for FrankenPHP
- [x] Add support for the full-stack apps (Front-end assets)
- [ ] Add support `testing` environment and CI
- [x] Add support for the Laravel scheduler
- [ ] Add support for Laravel Dusk
- [x] Support more PHP extensions
- [x] Add tests
- [ ] Add Alpine-based images

## Contributing

Thank you for considering contributing! If you find an issue, or have a better way to do something, feel free to open an
issue, or a PR.

## Credits
- [SMortexa](https://github.com/smortexa)
- [All contributors](https://github.com/exaco/laravel-octane-dockerfile/graphs/contributors)

## License

This repository is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
