# frozen_string_literal: true

# Test deployment workflow with automatic GitOps
require 'sinatra'
require 'json'
require 'httparty'
require 'securerandom'
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/sinatra'
require 'opentelemetry/instrumentation/http'
require 'prometheus/client'
require 'prometheus/client/formats/text'
require 'pg'
require 'connection_pool'

# Structured logging configuration
class StructuredLogger
  def initialize
    @base_fields = {
      service: 'ruby-demo-app',
      version: '1.3.0',
      environment: ENV.fetch('RACK_ENV', 'production')
    }
  end

  def info(message, **fields)
    log('INFO', message, **fields)
  end

  def error(message, **fields)
    log('ERROR', message, **fields)
  end

  def warn(message, **fields)
    log('WARN', message, **fields)
  end

  private

  def log(level, message, **fields)
    log_entry = @base_fields.merge(
      timestamp: Time.now.utc.iso8601,
      level: level,
      message: message,
      **fields
    )
    puts JSON.generate(log_entry)
  end
end

# Store app start time
START_TIME = Time.now

APP_LOGGER = StructuredLogger.new

# Database connection setup
# Construct DATABASE_URL from individual env vars for security
DB_USER = ENV.fetch('DB_USER', 'ruby_demo_user')
DB_PASSWORD = ENV.fetch('POSTGRES_PASSWORD', 'changeme')
DB_HOST = ENV.fetch('DB_HOST', 'postgresql')
DB_PORT = ENV.fetch('DB_PORT', '5432')
DB_NAME = ENV.fetch('DB_NAME', 'ruby_demo')

DATABASE_URL = ENV['DATABASE_URL'] || "postgresql://#{DB_USER}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{DB_NAME}"

def setup_database
  conn = PG.connect(DATABASE_URL)

  # Create visits table if it doesn't exist
  conn.exec <<-SQL
    CREATE TABLE IF NOT EXISTS visits (
      id SERIAL PRIMARY KEY,
      endpoint VARCHAR(255) NOT NULL,
      visited_at TIMESTAMP NOT NULL DEFAULT NOW(),
      user_agent TEXT,
      ip_address VARCHAR(45)
    )
  SQL

  # Create index on endpoint
  conn.exec <<-SQL
    CREATE INDEX IF NOT EXISTS idx_visits_endpoint ON visits(endpoint)
  SQL

  APP_LOGGER.info('Database schema initialized successfully')
  conn.close
rescue PG::Error => e
  APP_LOGGER.error('Failed to initialize database schema', error: e.message)
  raise
end

# Initialize database schema on startup
setup_database

# Database connection pool for concurrent requests
DB_POOL = ConnectionPool.new(size: 5, timeout: 5) do
  PG.connect(DATABASE_URL)
end

# Helper method to execute database queries
def with_db(&)
  DB_POOL.with(&)
rescue PG::Error => e
  APP_LOGGER.error('Database query failed', error: e.message)
  raise
end

# Prometheus metrics configuration
prometheus = Prometheus::Client.registry

# Application info metric
app_info = prometheus.gauge(
  :app_info,
  docstring: 'Application information',
  labels: %i[version environment service]
)
app_info.set(1,
             labels: { version: '1.3.0', environment: ENV.fetch('RACK_ENV', 'production'), service: 'ruby-demo-app' })

# Process start time for uptime calculation
process_start_time = prometheus.gauge(
  :process_start_time_seconds,
  docstring: 'Start time of the process since unix epoch in seconds'
)
process_start_time.set(START_TIME.to_f)

# HTTP request metrics
http_requests_total = prometheus.counter(
  :http_requests_total,
  docstring: 'Total number of HTTP requests',
  labels: %i[method path status]
)

http_request_duration = prometheus.histogram(
  :http_request_duration_seconds,
  docstring: 'Duration of HTTP requests in seconds',
  labels: %i[method path status],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# Configure OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = 'ruby-demo-app'
  c.service_version = '1.3.0'

  # Add OTLP exporter for metrics and traces
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 'http://tempo:4318/v1/traces'),
        headers: {}
      )
    )
  )

  # Add metrics exporter - Tempo will generate span metrics and send to Mimir
  # For now, we'll rely on Tempo's metrics generator for span-based metrics

  # Use instrumentation
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
  c.use 'OpenTelemetry::Instrumentation::HTTP'
end

# Configure Sinatra
set :bind, '0.0.0.0'
set :port, 4567
set :environment, :production

# OpenTelemetry setup
tracer = OpenTelemetry.tracer_provider.tracer('ruby-demo-app')

# Middleware to track metrics and tracing
before do
  @start_time = Time.now
  @request_id = SecureRandom.hex(8)
  @span = tracer.start_span("#{request.request_method} #{request.path}")
  @span.set_attribute('http.method', request.request_method)
  @span.set_attribute('http.url', request.url)
  @span.set_attribute('http.route', request.path)
  @span.set_attribute('request.id', @request_id)

  # Log request start
  APP_LOGGER.info('Request started',
                  request_id: @request_id,
                  method: request.request_method,
                  path: request.path,
                  user_agent: request.user_agent,
                  ip: request.ip)
end

after do
  duration = Time.now - @start_time
  status_code = response.status.to_s

  # Record Prometheus metrics
  http_requests_total.increment(
    labels: {
      method: request.request_method,
      path: request.path,
      status: status_code
    }
  )

  http_request_duration.observe(
    duration,
    labels: {
      method: request.request_method,
      path: request.path,
      status: status_code
    }
  )

  # Complete span with rich attributes for metrics generation
  if @span
    @span.set_attribute('http.status_code', response.status)
    @span.set_attribute('http.response_size', response.body.length) if response.body
    @span.set_attribute('http.duration', duration)
    @span.set_attribute('service.name', 'ruby-demo-app')
    @span.set_attribute('service.version', '1.3.0')

    # Set span status
    @span.status = response.status >= 400 ? OpenTelemetry::Trace::Status.error : OpenTelemetry::Trace::Status.ok
    @span.finish
  end

  # Log request completion
  log_level = response.status >= 400 ? :error : :info
  APP_LOGGER.send(log_level, 'Request completed',
                  request_id: @request_id,
                  method: request.request_method,
                  path: request.path,
                  status: response.status,
                  duration_ms: (duration * 1000).round(2),
                  response_size: response.body&.length)
end

# Routes
get '/' do
  content_type :json
  {
    message: 'Ruby Demo Application - Clean Architecture',
    version: '1.3.0',
    uptime: Time.now - START_TIME,
    timestamp: Time.now.iso8601,
    architecture: 'platform/applications separation',
    deployment_status: 'automatic image updates via Flux'
  }.to_json
end

get '/health' do
  content_type :json
  uptime_seconds = Time.now - START_TIME

  tracer.in_span('health_check') do |span|
    span.set_attribute('health.status', 'healthy')
    span.set_attribute('app.uptime', uptime_seconds)
    span.set_attribute('service.name', 'ruby-demo-app')

    {
      status: 'healthy',
      uptime: uptime_seconds,
      timestamp: Time.now.iso8601,
      observability: 'LGTM stack with OpenTelemetry'
    }.to_json
  end
end

get '/metrics' do
  content_type 'text/plain; version=0.0.4; charset=utf-8'

  # Return Prometheus metrics in text format
  Prometheus::Client::Formats::Text.marshal(prometheus)
end

get '/metrics/info' do
  content_type :json

  # Information endpoint about observability stack
  uptime_seconds = Time.now - START_TIME

  tracer.in_span('metrics_info') do |span|
    span.set_attribute('service.name', 'ruby-demo-app')
    span.set_attribute('app.uptime', uptime_seconds)

    {
      message: 'Observability via LGTM stack',
      architecture: {
        traces: 'OpenTelemetry → Tempo → Grafana',
        metrics: 'Prometheus → Alloy → Mimir → Grafana',
        logs: 'Docker logs → Alloy → Loki → Grafana'
      },
      endpoints: {
        traces: ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 'http://tempo:4318/v1/traces'),
        prometheus_metrics: '/metrics',
        grafana: 'https://grafana.lvs.me.uk'
      },
      uptime: uptime_seconds,
      timestamp: Time.now.iso8601
    }.to_json
  end
end

# External service monitoring
get '/monitor' do
  content_type :json

  services = [
    { name: 'grafana', url: 'http://grafana:3000/api/health' },
    { name: 'mimir', url: 'http://mimir:8080/ready' },
    { name: 'loki', url: 'http://loki:3100/ready' },
    { name: 'tempo', url: 'http://tempo:3200/ready' }
  ]

  tracer.in_span('monitor_services') do |span|
    span.set_attribute('services.count', services.length)

    results = services.map do |service|
      tracer.in_span("check_#{service[:name]}") do |service_span|
        service_span.set_attribute('service.name', service[:name])
        service_span.set_attribute('service.url', service[:url])

        start_time = Time.now
        response = HTTParty.get(service[:url], timeout: 5)
        duration = Time.now - start_time

        service_span.set_attribute('http.status_code', response.code)
        service_span.set_attribute('http.response_time', duration)

        {
          service: service[:name],
          status: response.success? ? 'up' : 'down',
          response_time: duration,
          http_code: response.code
        }
      rescue StandardError => e
        service_span.set_attribute('error', true)
        service_span.set_attribute('error.message', e.message)

        {
          service: service[:name],
          status: 'error',
          error: e.message,
          response_time: nil,
          http_code: nil
        }
      end
    end

    span.set_attribute('monitoring.results_count', results.length)

    {
      monitoring_results: results,
      timestamp: Time.now.iso8601,
      observability_stack: 'LGTM (Loki, Grafana, Tempo, Mimir)'
    }.to_json
  end
end

# Static info endpoint
get '/info' do
  content_type :json
  {
    application: 'Ruby Monitor',
    version: '1.0.0',
    ruby_version: RUBY_VERSION,
    sinatra_version: Sinatra::VERSION,
    hostname: `hostname`.strip,
    uptime: Time.now - START_TIME
  }.to_json
end

# Database test endpoint
# rubocop:disable Metrics/BlockLength
get '/db/test' do
  content_type :json

  tracer.in_span('db_test') do |span|
    span.set_attribute('service.name', 'ruby-demo-app')

    # Insert a new visit record
    with_db do |conn|
      conn.exec_params(
        'INSERT INTO visits (endpoint, user_agent, ip_address) VALUES ($1, $2, $3)',
        ['/db/test', request.user_agent, request.ip]
      )
    end

    # Get total visit count
    total_visits = with_db do |conn|
      result = conn.exec('SELECT COUNT(*) FROM visits')
      result[0]['count'].to_i
    end

    # Get visits for this endpoint
    endpoint_visits = with_db do |conn|
      result = conn.exec_params(
        'SELECT COUNT(*) FROM visits WHERE endpoint = $1',
        ['/db/test']
      )
      result[0]['count'].to_i
    end

    # Get recent visits (last 10)
    recent_visits = with_db do |conn|
      result = conn.exec_params(
        'SELECT endpoint, visited_at, ip_address FROM visits ORDER BY visited_at DESC LIMIT 10',
        []
      )
      result.map do |row|
        {
          endpoint: row['endpoint'],
          visited_at: row['visited_at'],
          ip_address: row['ip_address']
        }
      end
    end

    span.set_attribute('db.total_visits', total_visits)
    span.set_attribute('db.endpoint_visits', endpoint_visits)

    APP_LOGGER.info('Database test completed',
                    total_visits: total_visits,
                    endpoint_visits: endpoint_visits)

    {
      status: 'success',
      message: 'Database connection working!',
      database: 'ruby_demo',
      statistics: {
        total_visits: total_visits,
        endpoint_visits: endpoint_visits
      },
      recent_visits: recent_visits,
      timestamp: Time.now.iso8601
    }.to_json
  end
rescue PG::Error => e
  status 500
  APP_LOGGER.error('Database test failed', error: e.message)
  {
    status: 'error',
    message: 'Database connection failed',
    error: e.message,
    timestamp: Time.now.iso8601
  }.to_json
end
# rubocop:enable Metrics/BlockLength

# 404 handler
not_found do
  content_type :json
  status 404
  { error: 'Not found', path: request.path }.to_json
end

APP_LOGGER.info('Application starting',
                port: 4567,
                environment: ENV.fetch('RACK_ENV', 'production'),
                endpoints: {
                  health: '/health',
                  metrics: '/metrics',
                  monitor: '/monitor'
                })

APP_LOGGER.info('Application ready to serve requests')
