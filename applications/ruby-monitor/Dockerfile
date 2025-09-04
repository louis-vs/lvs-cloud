FROM ruby:3.2-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache curl build-base

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without development test

# Copy application code
COPY . .

# Expose port
EXPOSE 4567

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4567/health || exit 1

# Run the application
CMD ["ruby", "app.rb"]
