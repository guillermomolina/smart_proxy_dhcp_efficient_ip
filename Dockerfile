FROM ubuntu:latest

RUN apt update
RUN apt install -y build-essential ruby-full git
RUN gem install bundler

WORKDIR /code
RUN git clone --single-branch --branch 2.3-stable https://github.com/theforeman/smart-proxy.git
COPY ./config/docker_smart-proxy_settings /code/smart-proxy/config
COPY . /code/smart_proxy_efficient_ip
RUN gem install json -v '~> 1.8'
RUN gem install rest-client -v '~> 2.0'
RUN gem install --local /code/smart_proxy_efficient_ip/vendor/SOLIDserver-0.0.11.gem
WORKDIR /code/smart-proxy
RUN echo ':http_port: 4567' > config/settings.yml
RUN echo 'gem "smart_proxy_efficient_ip", path: "../smart_proxy_efficient_ip"' > bundler.d/smart_proxy_efficient_ip.rb
RUN bundle install --without test development libvirt journald windows krb5

EXPOSE 4567

CMD ["./bin/smart-proxy"]
