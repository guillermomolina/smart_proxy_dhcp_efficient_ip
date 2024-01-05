FROM debian:bookworm-slim

ARG FOREMAN_VERSION

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
			build-essential ruby-full git libkrb5-dev && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /code
RUN git clone --single-branch --branch ${FOREMAN_VERSION}-stable https://github.com/theforeman/smart-proxy.git
COPY . /code/smart_proxy_efficient_ip

RUN gem install \
        bundler xmlrpc rkerberos

WORKDIR /code/smart-proxy
RUN mv config /etc/foreman-proxy && \
    ln -s /etc/foreman-proxy config  && \
    echo ':http_port: 9000' > config/settings.yml
COPY ./config/docker_smart-proxy_settings/settings.d /etc/foreman-proxy/settings.d

RUN echo 'gem "smart_proxy_efficient_ip", path: "../smart_proxy_efficient_ip"' > bundler.d/smart_proxy_efficient_ip.rb && \
    echo 'gem "SOLIDserver", git: "https://github.com/guillermomolina/ruby-gem-efficientIP.git", branch: "gam-new-features"' > bundler.d/SOLIDserver.rb

RUN bundle config set --local without 'test development libvirt journald windows krb5' && \
    bundle install

EXPOSE 9000

CMD ["./bin/smart-proxy"]
