#!/bin/sh

envsubst \
    < /conf/openidc.conf \
    > /tmp/openidc.conf
mv -f /tmp/openidc.conf /conf/openidc.conf

envsubst \
    < /conf/vhost.conf \
    > /tmp/vhost.conf
mv -f /tmp/vhost.conf /conf/vhost.conf

envsubst \
    < /conf/location.conf \
    > /tmp/location.conf
mv -f /tmp/location.conf /conf/location.conf

httpd-foreground
