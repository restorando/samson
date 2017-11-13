FROM ruby:2.4.1-slim

RUN apt-get update && apt-get install -y build-essential libmysqlclient-dev libpq-dev libsqlite3-dev wget apt-transport-https git curl
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - && apt-get install nodejs

WORKDIR /app

# Mostly static
COPY config.ru /app/
COPY Rakefile /app/
COPY bin /app/bin
COPY public /app/public
COPY db /app/db
COPY .env.bootstrap /app/.env
COPY .ruby-version /app/.ruby-version

# NPM
COPY package.json /app/package.json
RUN npm install

# Gems
COPY Gemfile /app/
COPY Gemfile.lock /app/
COPY vendor/cache /app/vendor/cache
COPY plugins /app/plugins

RUN bundle install --quiet --jobs 4 || bundle check

# Code
COPY config /app/config
COPY app /app/app
COPY lib /app/lib

# Assets
COPY vendor/assets /app/vendor/assets
RUN echo "takes 5 minute" && RAILS_ENV=production PRECOMPILE=1 bundle exec rake assets:precompile

RUN mkdir ~/.ssh
RUN echo 'IdentityFile ~/.ssh-local/id_rsa' > ~/.ssh/config

EXPOSE 9080

CMD ["bundle", "exec", "puma", "-C", "./config/puma.rb"]
