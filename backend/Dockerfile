# Builds the Ruby API into a container image. Vercel runs the backend from
# this image, because its built-in Ruby runtime cannot load the Postgres
# driver.

# This has to be the Ruby version the project is pinned to, or installing
# the gems fails. "slim" is a small Debian Linux with Ruby installed and
# little else.
FROM ruby:4.0.9-slim

# A few gems contain C code that is compiled when they are installed, which
# needs a compiler.
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Leaves out the gems that are only used for testing and linting.
ENV BUNDLE_WITHOUT="development:test"

# The gems are installed before the rest of the code is copied in. Docker
# reuses this step from its cache until the Gemfile changes, so editing a
# Ruby file does not reinstall every gem.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install

COPY . .

# APP_ENV and RACK_ENV switch Sinatra and the server out of development
# mode. PORT is 80 because that is where Vercel sends a container's
# requests.
#
# DATABASE_URL is not set here. It holds a password, so it comes from the
# project's environment variables on Vercel.
ENV APP_ENV=production \
    RACK_ENV=production \
    PORT=80

# `--host 0.0.0.0` makes the server accept requests from outside the
# container.
CMD ["sh", "-c", "bundle exec rackup --host 0.0.0.0 --port $PORT"]
