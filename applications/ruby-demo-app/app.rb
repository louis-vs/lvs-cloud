# frozen_string_literal: true

# Test deployment workflow with automatic GitOps
require 'sinatra'
require 'json'
require 'httparty'
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/sinatra'
require 'opentelemetry/instrumentation/http'

# Configure OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = 'ruby-demo-app'
  c.service_version = '1.2.0'

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
OpenTelemetry.meter_provider.meter('ruby-demo-app')

# Create custom attributes for spans (metrics will be generated from spans via Tempo)
# Tempo's metrics generator will create span-based metrics automatically

# Store app start time
START_TIME = Time.now

# Middleware to track metrics and tracing
before do
  @start_time = Time.now
  @span = tracer.start_span("#{request.request_method} #{request.path}")
  @span.set_attribute('http.method', request.request_method)
  @span.set_attribute('http.url', request.url)
  @span.set_attribute('http.route', request.path)
end

after do
  duration = Time.now - @start_time

  # Complete span with rich attributes for metrics generation
  if @span
    @span.set_attribute('http.status_code', response.status)
    @span.set_attribute('http.response_size', response.body.length) if response.body
    @span.set_attribute('http.duration', duration)
    @span.set_attribute('service.name', 'ruby-demo-app')
    @span.set_attribute('service.version', '1.2.0')

    # Set span status
    @span.status = response.status >= 400 ? OpenTelemetry::Trace::Status.error : OpenTelemetry::Trace::Status.ok
    @span.finish
  end
end

# Routes
get '/' do
  content_type :json
  {
    message: 'Ruby Demo Application - Clean Architecture',
    version: '1.1.1',
    uptime: Time.now - START_TIME,
    timestamp: Time.now.iso8601,
    architecture: 'platform/applications separation',
    deployment_status: 'json formatting fixed'
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
  content_type :json

  # Legacy endpoint for backwards compatibility
  # Traces are sent to Tempo, which generates span metrics and sends them to Mimir
  uptime_seconds = Time.now - START_TIME

  tracer.in_span('metrics_info') do |span|
    span.set_attribute('service.name', 'ruby-demo-app')
    span.set_attribute('app.uptime', uptime_seconds)

    {
      message: 'Observability via LGTM stack',
      architecture: {
        traces: 'OpenTelemetry → Tempo → Grafana',
        metrics: 'Tempo span metrics → Mimir → Grafana',
        logs: 'Docker logs → Loki → Grafana'
      },
      endpoints: {
        traces: ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 'http://tempo:4318/v1/traces'),
        tempo_ui: 'https://tempo.lvs.me.uk',
        mimir_ui: 'https://mimir.lvs.me.uk',
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

# 404 handler
not_found do
  content_type :json
  status 404
  { error: 'Not found', path: request.path }.to_json
end

puts 'Ruby Monitor starting on port 4567...'
puts 'Metrics available at /metrics'
puts 'Health check at /health'
