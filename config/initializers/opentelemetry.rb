# Standard OpenTelemetry setup following the official documentation
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"
require "opentelemetry/sdk/trace/export/console_span_exporter"
require "net/http"
require "json"

# Function to fetch OIDC token
def fetch_oidc_token
  client_id = ENV.fetch("OTEL_CLIENT_ID", "liveheats-agent")
  client_secret = ENV.fetch("OTEL_CLIENT_SECRET", "Uuu7LhVdsfDZqKK6ChmxfODFKYsultIq")
  token_url = ENV.fetch("OTEL_TOKEN_URL", "https://id.b14.dev/realms/liveheats/protocol/openid-connect/token")
  
  uri = URI(token_url)
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(
    "grant_type" => "client_credentials",
    "client_id" => client_id,
    "client_secret" => client_secret
  )
  
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end
  
  if response.is_a?(Net::HTTPSuccess)
    puts "Fetched OIDC token: #{JSON.parse(response.body)["access_token"]}"
    JSON.parse(response.body)["access_token"]
  else
    Rails.logger.error "Failed to fetch OIDC token: #{response.body}"
    nil
  end
end

# Configure OpenTelemetry
OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "hotel-food-app")
  
  # Get the endpoint from environment or use the default
  endpoint = ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT", "https://otel.play.base14.io/01jvsbqh714xh44zxjk9d5a70j/otlp")
  
  # Fetch the token first
  token = fetch_oidc_token
  headers = {}
  headers["Authorization"] = "Bearer #{token}" if token
  
  # Setup OTLP exporter with authentication
  otlp_exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
    endpoint: endpoint,
    headers: headers
  )
  
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(otlp_exporter)
  )

  c.use_all()
end

module OpenTelemetryLoggingExtension
  def self.extended(base)
    class << base
      alias_method :original_formatter, :formatter if method_defined?(:formatter)
      def formatter
        proc do |severity, timestamp, progname, msg|
          current_span = OpenTelemetry::Trace.current_span
          trace_id = current_span.context.hex_trace_id
          span_id = current_span.context.hex_span_id
          original_format = if respond_to?(:original_formatter) && original_formatter
                             original_formatter.call(severity, timestamp, progname, msg)
          else
                             "#{severity} [#{timestamp}]: #{msg}\n"
          end
          "[trace_id=#{trace_id} span_id=#{span_id}] #{original_format}"
        end
      end
    end
  end
end

# Configure to apply our extension after Rails is initialized
Rails.application.config.to_prepare do
  # Only add once to avoid duplicating
  unless Rails.logger.class.name.include?("OpenTelemetryLoggingExtension")
    # Apply our OpenTelemetry logging extension
    Rails.logger.extend(OpenTelemetryLoggingExtension)
    # Log that we've initialized the logging extension
    Rails.logger.info "OpenTelemetry logging extension initialized"
  end
end
