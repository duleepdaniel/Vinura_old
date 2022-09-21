FROM ruby:3.0.0-alpine as Builder

RUN apk add --update --no-cache \
    build-base \
    postgresql-dev \
    git \
    imagemagick imagemagick6-dev imagemagick6-libs \
    nodejs-current \
    yarn \
    tzdata \
    gcompat

WORKDIR /app

ENV BUNDLER_VERSION=2.2.3

# Install gems
RUN gem install bundler -v 2.2.3

ADD Gemfile* /app/
RUN bundle config --global frozen 1 \
 && bundle install --without development test -j4 --retry 3 \
 && rm -rf /usr/local/bundle/cache/*.gem \
 && find /usr/local/bundle/gems/ -name "*.c" -delete \
 && find /usr/local/bundle/gems/ -name "*.o" -delete

# Install yarn packages
COPY yarn.lock /app/
RUN yarn install

# Add the Rails app
ADD . /app

# Precompile assets
RUN RAILS_ENV=production SECRET_TOKEN=sampletoken bundle exec rake assets:precompile

# Remove folders not needed in resulting image
RUN rm -rf node_modules tmp/cache app/assets vendor/assets lib/assets spec

# ###############################
# # Stage wkhtmltopdf
# FROM madnight/docker-alpine-wkhtmltopdf as wkhtmltopdf

# ###############################
# # Stage Final
FROM ruby:3.0.0-alpine
LABEL maintainer="mail@duleep.daniel@gmail.com"

# Add Alpine packages
RUN apk add --update --no-cache \
    postgresql-client \
    imagemagick \
    tzdata \
    file \
    ttf-dejavu ttf-droid ttf-freefont ttf-liberation ttf-ubuntu-font-family

# Add user
RUN addgroup -g 1000 -S app \
 && adduser -u 1000 -S app -G app
USER app

# Copy app with gems from former build stage
COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=Builder --chown=app:app /app /app

# Set Rails env

WORKDIR /app

# Expose Puma port
EXPOSE 3000

# Save timestamp of image building
RUN date -u > BUILD_TIME

# Start up
ENTRYPOINT ["docker/startup.sh"]

# Start up
CMD bundle exec puma -C config/puma.rb
