php() {
    echo "Running PHP as octane user ..."
    su octane -c "php $*"
}

tinker() {
    if [ -z "$l" ]; then
        php artisan tinker
    else
        php artisan tinker --execute="dd($l);"
    fi
}
