FROM ruby:3.3-alpine as production

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache curl build-base postgresql-dev postgresql-client

# Configure bundler for production
ENV BUNDLE_WITHOUT="development test"
ENV BUNDLE_DEPLOYMENT="true"
ENV BUNDLE_PATH="/usr/local/bundle"

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle config set --local deployment 'true' && \
    bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Expose port
EXPOSE 4567

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4567/health || exit 1

# Run the application with bundle exec to ensure proper gem paths
CMD ["bundle", "exec", "ruby", "app.rb"]
