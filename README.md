# Laravel Octane Dockerfile

A pretty configurable and production ready multi-stage Dockerfile for [Laravel Octane](https://github.com/laravel/octane)
powered web services and microservices.

The Docker configuration provides the following setup:

- Debian Buster 10
- PHP 8.0 with preconfigured JIT compiler and OPcache
- Swoole extension with support of:
    - OpenSSL
    - HTTP/2
    - Native cURL hook for coroutines
    - `mysqlnd`
    - Asynchronous DNS

## PHP extensions

And the following PHP extensions are included:

- [x] Swoole
- [x] OPcache
- [x] Redis
- [x] PCNTL
- [x] BCMath
- [x] RDKAFKA
- [x] INTL
- [x] pdo_mysql
- [x] MySQL Client
- [x] zip
- [x] cURL
- [x] GD
- [x] mbstring

## Ports

Exposed ports of container:

| Software | Port |
|-------------- | -------------- |
| Swoole | 9000 |

## Usage

1. Clone this repository:

   `git clone git@github.com:exaco/laravel-octane-dockerfile.git`

2. Copy cloned directory content including `deployment` directory, `Dockerfile` and `.dockerignore` into your Octane
   powered Laravel project
3. Change directory to your Laravel project
4. Build your image:

   `docker build -t <container-name>:<tag> .`

5. Up the container:

   `docker run -p <port>:9000 --rm <container-name>:<tag>`

6. Visit `http://localhost:<port>`

### Use in Laravel Sail

You can use this Dockerfile within Laravel Sail. Just change PHP container `context` to `.` and add `<port>:9000`
to `ports` in `docker-compose.yml`. You maybe need to remove `WWWGROUP` in `args` and `WWWUSER` in `environment`
configuration in this file.

## Configuration

There are something that you maybe want to configure:

- Application request workers count in `supervisord.conf`
- Max request count for request workers in `supervisord.conf`
- The amount of workers available to process concurrent tasks in `supervisord.conf`
- OPcache and JIT configurations in `opcache.ini`
- PHP configurations in `php.ini`
- `ENTRYPOINT` Bash script in `entrypoint.sh`
- Set OS timezone using the `--build-arg` option along with the build command

### Recommended Swoole options in `octane.php`

```php
// config/octane.php

return [
    'swoole' => [
            'options' => [
                'user' => 'octane',
                'group' => 'octane',
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

## Contributing

Thank you for considering contributing! If you find an issue, or have a better way to do something, feel free to open an
issue, or a PR.

## License

This repository is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).