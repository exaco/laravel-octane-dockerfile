# Laravel Octane Dockerfile

A pretty configurable, production-ready and multi-stage Dockerfile for [Laravel Octane](https://github.com/laravel/octane)
powered web services and microservices.

The Docker configuration provides the following setup:

- PHP 8.0 and 8.1 official DebianBuster-based images
- Preconfigured JIT compiler and OPcache

## Container modes

| Mode | `CONTAINER_MODE` ARG | Supervisor config file | HTTP server | Exposed port |
|------------ | ------------ | ------------ | ------------ | ------------ |
| Octane (default) | `app` | [supervisord.app.conf](deployment/octane/supervisord.app.conf) | Swoole | 9000 |
| Horizen | `horizon` | [supervisord.horizon.conf](deployment/octane/supervisord.horizon.conf) | - | - |

> If you want to run Horizon in the Octane container, then you should set `APP_WITH_HORIZON` build argument `true`.

## PHP extensions

And the following PHP extensions are included:

- [x] Swoole with support of OpenSSL, HTTP/2, Native cURL hook for coroutines, `mysqlnd` and asynchronous DNS.
- [x] OPcache
- [x] Redis
- [x] PCNTL
- [x] BCMath
- [x] RDKAFKA
- [x] INTL
- [x] pdo_mysql
- [x] pdo_pgsql (disabled by default)
- [x] pgsql (disabled by default)
- [x] Memcached (disabled by default)
- [x] zip
- [x] cURL
- [x] GD
- [x] mbstring

## Usage

1. Clone this repository:
```
git clone --depth 1 git@github.com:exaco/laravel-octane-dockerfile.git
```
2. Copy cloned directory content including `deployment` directory, `Dockerfile` and `.dockerignore` into your Octane powered Laravel project
3. Change directory to your Laravel project
4. Build your image:

- Container `app` mode:
```
docker build -t <image-name>:<tag> .
```
- Container `horizon` mode:
```
docker build -t <image-name>:<tag> --build-arg CONTAINER_MODE=horizon .
```
5. Up the container:
```
docker run -p <port>:9000 --rm <image-name>:<tag>
```

## Configuration

There are something that you maybe want to configure:

- Swoole HTTP server config in `supervisord.app.conf`
- OPcache and JIT configurations in `opcache.ini`
- PHP configurations in `php.ini`
- `ENTRYPOINT` Bash script in `entrypoint.sh`
- Set `PHP_VERSION` using the `--build-arg` option along with the build command
- Set `TZ` (OS timezone) using the `--build-arg` option along with the build command

### Recommended options for `octane.php`

```php
// config/octane.php

return [
    'listeners' => [
        OperationTerminated::class => [
            FlushTemporaryContainerInstances::class,
            DisconnectFromDatabases::class, // uncomment this line
            // CollectGarbage::class,
        ],
    ],
    'swoole' => [
        'options' => [
            'http_compression' => true,
            'http_compression_level' => 6, // 1 - 9
            'compression_min_length' => 20,
            'open_http2_protocol' => true,
            'open_cpu_affinity' => true,
            'tcp_fastopen' => true,
            'open_tcp_keepalive' => true,
            'open_tcp_nodelay' => true,
            'enable_reuse_port' => true,
        ]
    ]
];
```

## Utilities

Also, some useful Bash functions and aliases are added in `utilities.sh` that maybe help.

## Notes

- Laravel Octane logs requests information only in the `local` environment.
- Please be aware about `.dockerignore` content

## ToDo
- [x] Add support for Horizon
- [ ] Add support for RoadRunner
- [ ] Add support for the full stack apps (Front-end assets)
- [ ] Add support `testing` environment and CI
- [ ] Add support for Laravel scheduler
- [ ] Add support for Laravel Dusk
- [ ] Support more PHP extensions

## Contributing

Thank you for considering contributing! If you find an issue, or have a better way to do something, feel free to open an
issue, or a PR.

## License

This repository is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
