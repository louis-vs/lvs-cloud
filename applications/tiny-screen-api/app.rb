# frozen_string_literal: true

require 'sinatra'
require 'json'

get '/' do
  content_type :json
  { am_i_winning: 'yes' }.to_json
end

get '/health' do
  content_type :json
  { status: 'healthy' }.to_json
end

# 404 handler
not_found do
  content_type :json
  status 404
  { error: 'Not found', path: request.path }.to_json
end

puts 'App Started'
