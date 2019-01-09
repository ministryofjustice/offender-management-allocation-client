require 'yaml'
threads_number = Integer(ENV['RAILS_MAX_THREADS'] || 5)
workers Integer(ENV['WEB_CONCURRENCY'] || 1)
threads threads_number, threads_number

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'production'

after_worker_boot do
  require 'prometheus_exporter/instrumentation'
  PrometheusExporter::Instrumentation::Puma.start
end

after_fork do
  require 'prometheus_exporter/instrumentation'
  PrometheusExporter::Instrumentation.process.start(type: 'web')
end
