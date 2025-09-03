require 'sinatra'
require 'json'
require 'prometheus/client'
require 'httparty'

# Configure Sinatra
set :bind, '0.0.0.0'
set :port, 4567
set :environment, :production

# Prometheus metrics setup
prometheus = Prometheus::Client.registry
uptime_gauge = prometheus.gauge(:app_uptime_seconds, docstring: 'Application uptime in seconds')
request_counter = prometheus.counter(:http_requests_total, docstring: 'Total HTTP requests', labels: [:method, :path, :status])
response_time_histogram = prometheus.histogram(:http_request_duration_seconds, docstring: 'HTTP request duration')

# Store app start time
START_TIME = Time.now

# Middleware to track metrics
before do
  @start_time = Time.now
end

after do
  duration = Time.now - @start_time
  response_time_histogram.observe(duration)
  request_counter.increment(labels: { method: request.request_method, path: request.path, status: response.status })
end

# Routes
get '/' do
  content_type :json
  {
    message: "Ruby Monitor Application",
    version: "1.0.0",
    uptime: Time.now - START_TIME,
    timestamp: Time.now.iso8601
  }.to_json
end

get '/health' do
  content_type :json
  uptime_seconds = Time.now - START_TIME
  uptime_gauge.set(uptime_seconds)
  
  {
    status: "healthy",
    uptime: uptime_seconds,
    timestamp: Time.now.iso8601
  }.to_json
end

get '/metrics' do
  content_type 'text/plain; version=0.0.4'
  
  # Update uptime metric
  uptime_gauge.set(Time.now - START_TIME)
  
  Prometheus::Client::Formats::Text.marshal(prometheus)
end

# External service monitoring
get '/monitor' do
  content_type :json
  
  services = [
    { name: "grafana", url: "http://grafana:3000/api/health" },
    { name: "prometheus", url: "http://prometheus:9090/-/healthy" },
    { name: "loki", url: "http://loki:3100/ready" }
  ]
  
  results = services.map do |service|
    begin
      start_time = Time.now
      response = HTTParty.get(service[:url], timeout: 5)
      duration = Time.now - start_time
      
      {
        service: service[:name],
        status: response.success? ? "up" : "down",
        response_time: duration,
        http_code: response.code
      }
    rescue => e
      {
        service: service[:name],
        status: "error",
        error: e.message,
        response_time: nil,
        http_code: nil
      }
    end
  end
  
  {
    monitoring_results: results,
    timestamp: Time.now.iso8601
  }.to_json
end

# Static info endpoint
get '/info' do
  content_type :json
  {
    application: "Ruby Monitor",
    version: "1.0.0",
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
  { error: "Not found", path: request.path }.to_json
end

puts "Ruby Monitor starting on port 4567..."
puts "Metrics available at /metrics"
puts "Health check at /health"