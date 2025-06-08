# Standard OpenTelemetry setup following the official documentation
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"
require "opentelemetry/sdk/trace/export/console_span_exporter"

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "hotel-food-app")
  
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new
    )
  )

  c.use_all()
end

module OpenTelemetryLoggingExtension
  def self.extended(base)
    class << base
      alias_method :original_formatter, :formatter if method_defined?(:formatter)
      
      # Override the formatter method to add trace context
      def formatter
        proc do |severity, timestamp, progname, msg|
          # Get current OpenTelemetry context
          current_span = OpenTelemetry::Trace.current_span
          trace_id = current_span.context.hex_trace_id
          span_id = current_span.context.hex_span_id
          
          # Use original formatter if available, otherwise default format
          original_format = if respond_to?(:original_formatter) && original_formatter
                             original_formatter.call(severity, timestamp, progname, msg)
                           else
                             "#{severity} [#{timestamp}]: #{msg}\n"
                           end
                           
          # Add trace context to the formatted message
          "[trace_id=#{trace_id} span_id=#{span_id}] #{original_format}"
        end
      end
    end
  end
end

# Configure to apply our extension after Rails is initialized
Rails.application.config.to_prepare do
  # Only add once to avoid duplicating
  unless Rails.logger.class.name.include?('OpenTelemetryLoggingExtension')
    # Apply our OpenTelemetry logging extension
    Rails.logger.extend(OpenTelemetryLoggingExtension)
    # Log that we've initialized the logging extension
    Rails.logger.info "OpenTelemetry logging extension initialized"
  end
end
