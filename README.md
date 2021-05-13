## mod-auth-openidc-forwardauth

A Docker image for a forwardauth container based on the `mod_auth_openidc` Apache 2.x module. This image is meant to serve in conjunction with Traefik and other compatible reverse proxies. Claim requirements are configurable through Docker ENVs.

- [Why this image exists](#why-this-image-exists)
- [Quickstart](#quickstart)
- [Available ENVs / Claims configuration](#available-envs--claims-configuration)
  - [Arbitrary additional configuration](#arbitrary-additional-configuration)
- [`mod_auth_openidc` headers](#mod_auth_openidc-headers)
  - [Debugging headers](#debugging-headers)
- [Examples](#examples)

# Why this image exists

I use Keycloak for my personal services and wanted the ability to easily add authentication/authorization to internal apps without having to implement actual login/auth mechanisms for them. An easy way to do this for dockerized apps is to use Traefik as a reverse proxy and make use of its forwardAuth mechanism. I used [Thom Seddon's very useful image](https://github.com/thomseddon/traefik-forward-auth) for a while, but this only allows an explicit email address whitelist as a Docker ENV to limit access.

What I ultimately required was the ability to specify flexible claim requirements, as allowed by `mod_auth_openidc`. Unfortunately, there is no Docker image with `mod_auth_openidc` that works as a forwardAuth image, mostly because it is meant to act as a transparent module in cases where the app is included in the httpd container.

This image uses a workaround to make `mod_auth_openidc` work in a forwardAuth setting.

# Quickstart

Here is an example `docker-compose.yml` based on a Keycloak OpenID Connect provider:

```yaml
version: "3.8"

networks:
  app: {}

services:
  forwardauth:
    image: whefter/mod-auth-openidc-forwardauth
    networks:
      - app
    environment:
      OIDC_PROVIDER_METADATA_URL: https://keycloak.example.com/auth/realms/modauthopenidctest/.well-known/openid-configuration
      OIDC_CLIENT_ID: client-id
      OIDC_CLIENT_SECRET: client-secret
      OIDC_CRYPTO_PASSPHRASE: random-crypto-passphrase
      OIDC_REQUIRE_CLAIM: resource_access.client-id.roles:mod-auth-openidc-test-access

  traefik:
    image: traefik:v2.4
    networks:
      - app
    command:
      - "--log.level=DEBUG"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.constraints=Label(`traefik.tags`,`modauthopenidc-example`)"
      - "--entrypoints.web.address=:80"
    ports:
      - 80:80
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  app:
    image: my-app
    networks:
      - app
    labels:
      traefik.enable: "true"
      traefik.tags: modauthopenidc-example
      traefik.docker.network: modauthopenidctest_app
      traefik.http.routers.httpd.rule: Host(`localhost`)
      traefik.http.routers.httpd.entrypoints: web
      traefik.http.routers.httpd.service: httpd
      traefik.http.services.httpd.loadbalancer.server.port: "8080"
      traefik.http.middlewares.httpd_forwardauth.forwardauth.address: http://forwardauth:80/
      traefik.http.middlewares.traefik-forward-auth.forwardauth.authResponseHeaders: X-Forwarded-User
      traefik.http.routers.httpd.middlewares: httpd_forwardauth
```

In this example, Traefik sets the value of the `X-Forwarded-User` header returned from the forwardAuth container on the request, making it available to the app. See below for more information on returned headers.

# Available ENVs / Claims configuration

Note:
* for actual documentation on how to configure `mod_auth_openidc`, see https://github.com/zmartzone/mod_auth_openidc
* for actual documentation on how to configure Traefik and its ForwardAuth, see https://doc.traefik.io/traefik/middlewares/forwardauth/

For a full reference of available ENVs to configure `mod_auth_openidc`, check out [vhost.conf](./conf/vhost.conf).

Wherever possible, ENV names are identical to the `mod_auth_openidc` configuration directive, i.e. `OIDCProviderMetadataURL` -> `OIDC_PROVIDER_METADATA_URL`.

Of note are:
* `OIDC_PROVIDER_METADATA_URL`
* `OIDC_CLIENT_ID`
* `OIDC_CLIENT_SECRET`
* `OIDC_CRYPTO_PASSPHRASE`
* `OIDC_SCOPE` (default: `openid email`)
* `OIDC_REMOTE_USER_CLAIM` (default: `preferred_username`)
* `OIDC_REQUIRE_CLAIM` (default: empty)
* `OIDC_REQUIRE_CLAIM_1` through `OIDC_REQUIRE_CLAIM_10` (default: empty)

`OIDC_REQUIRE_CLAIM` ENVs are used to specify claims, see the quickstart example.

## Arbitrary additional configuration

A quick hassle-free way to add more specific configuration not available through the basic ENVs is through these two ENVs, the content of which is included directly in the Apache VHost and Location config blocks, respectively:
```yaml
  environment:
    OIDC_VHOST_EXTRA_CONFIG: |
      OIDCOAuthRemoteUserClaim Username
      OIDCSSLValidateServer
      ...
    OIDC_LOCATION_EXTRA_CONFIG: |
      Require claim ...
```
It is easily possible to completely break the configuration using this, especially with the Location block, since some of the "magic" is included in the Location block. Caution is advised.

Alternatively, additional configuration files can be included by mounting them inside the container:
* for the VHost configuration: `/conf/vhost.d/` and naming them `*.conf`
* for the Location configuration: `/conf/location.d/` and naming them `*.conf`

To **completely replace** the default configuration for advanced scenarios, the following files can be mounted. Mounting one or both of those files overwrites most of the default configuration, except the magic bits necessary for ForwardAuth functionality. Configuration through ENVs will not be available anymore, unless you make it so. You will be responsible for the full configuration.
* `/conf/vhost.conf`
* `/conf/location.conf`
**Note** that these files are subject to `envsubst` ENV substitution on container start.

# `mod_auth_openidc` headers

All headers set by `mod_auth_openidc` inside the forwardAuth container for the request and starting with `OIDC`, meaning to the best of my knowledge all headers set by the `mod_auth_openidc` module, are set as response headers on the forwardAuth response. This allows them to be sent to the app as request headers using, for example, Traefik's `authResponseHeaders` or `authResponseHeadersRegex` functionality.

This also (currently) includes the access token, which is set by `mod_auth_openidc` to the `OIDC-Access-Token` header, and the claims, set to the `OIDC-Claim-*` headers. Should `mod_auth_openidc` change its behavior related to these headers, this might change.

Security implications of sending headers with potentially sensitive data to the app should be considered.

## Debugging headers

If you're unsure which headers are available or otherwise need to debug their content, check out the `examples/echo-headers/` example, which employs the extremely useful `brndnmtthws/nginx-echo-headers` image to simply output all headers after successful authentication.

# Examples

See the `examples/` folder for available examples. More examples may be added in the future.
