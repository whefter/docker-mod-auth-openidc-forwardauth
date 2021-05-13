FROM httpd

RUN apt update \
    && apt install -y \
        wget \
    && wget -O /tmp/package.deb https://github.com/zmartzone/mod_auth_openidc/releases/download/v2.4.6/libapache2-mod-auth-openidc_2.4.6-1.buster+1_amd64.deb \
    && apt install -y /tmp/package.deb \
    && rm /tmp/package.deb \
    && apt remove -y wget \
    && apt install -y gettext-base \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /usr/local/apache2/htdocs/__modauthopenidc_auth__ \
    && echo "auth" > /usr/local/apache2/htdocs/__modauthopenidc_auth__/index.html \
    && mkdir /conf \
    && echo "Include /conf/openidc.conf" >> /usr/local/apache2/conf/httpd.conf

COPY conf/*.conf /conf/
COPY docker-cmd.sh /docker-cmd.sh

# Default values
ENV OIDC_PROVIDER_METADATA_URL=""
ENV OIDC_CLIENT_ID=""
ENV OIDC_CLIENT_SECRET=""
ENV OIDC_CRYPTO_PASSPHRASE=""
ENV OIDC_SCOPE="openid email"
ENV OIDC_REMOTE_USER_CLAIM="preferred_username"
ENV OIDC_VHOST_EXTRA_CONFIG=""
ENV OIDC_REQUIRE_CLAIM=""
ENV OIDC_REQUIRE_CLAIM_1=""
ENV OIDC_REQUIRE_CLAIM_2=""
ENV OIDC_REQUIRE_CLAIM_3=""
ENV OIDC_REQUIRE_CLAIM_4=""
ENV OIDC_REQUIRE_CLAIM_5=""
ENV OIDC_REQUIRE_CLAIM_6=""
ENV OIDC_REQUIRE_CLAIM_7=""
ENV OIDC_REQUIRE_CLAIM_8=""
ENV OIDC_REQUIRE_CLAIM_9=""
ENV OIDC_REQUIRE_CLAIM_10=""
ENV OIDC_LOCATION_EXTRA_CONFIG=""


CMD ["/docker-cmd.sh"]
