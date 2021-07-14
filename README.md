# Laravel Octane Dockerfile
A pretty configurable and production ready multi-stage Dockerfile for [Octane](https://github.com/laravel/octane) powered Laravel applications.

The Docker configuration provides the following setup:
- Debian Buster 10
- PHP 8.0
- Swoole Server


## PHP extensions

And the following PHP extensions are included:
- [x] Swoole
- [x] OPcache
- [x] Redis
- [x] PCNTL
- [x] BCMATH
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
| **Swoole** | 9000 |

## Usage

1. Clone this repository
    
    `git clone git@github.com:exaco/laravel-octane-dockerfile.git`
   
2. Copy cloned directory content into your Laravel project
3. Change directory to your Laravel project
3. Build your image
   
   `docker build -t laravel-octane:1.0 .`
   
4. Up the container

   `docker run -p 80:9000 --rm laravel-octane:1.0`

5. Visit `http://localhost`

## Configuration

There are something that you maybe want to configure:
- Application request workers count in `supervisord.conf`
- Max request count for request workers in `supervisord.conf`
- The amount of workers available to process concurrent tasks in `supervisord.conf`
- OPcache and JIT configurations in `opcache.ini`
- PHP configurations in `php.ini`
- `ENTRYPOINT` Bash script in `entrypoint.sh`

## Contributing

Thank you for considering contributing! If you find an issue, or have a better way to do something, feel free to open an issue, or a PR.


## License

This repository is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).