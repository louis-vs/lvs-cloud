json.extract! writer, :id, :first_name, :last_name, :ip_code, :created_at, :updated_at
json.url writer_url(writer, format: :json)
