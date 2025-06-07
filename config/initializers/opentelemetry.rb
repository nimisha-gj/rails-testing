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

  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
      OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter.new
    )
  )
  c.use_all()
end
