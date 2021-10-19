php() {
    echo "Running PHP as octane user ..."
    su octane -c "php $*"
}

tinker() {
    if [ -z "$1" ]; then
        php artisan tinker
    else
        php artisan tinker --execute="\"dd($1);\""
    fi
}
