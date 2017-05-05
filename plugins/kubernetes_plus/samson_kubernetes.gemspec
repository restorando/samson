# frozen_string_literal: true
Gem::Specification.new 'samson_kubernetes_plus', '0.0.1' do |s|
  s.description = s.summary = 'Add more introspection of Kubernetes deployments'
  s.authors = ['Juan Barreneche']
  s.email = 'jbarreneche@restorando.com'
  s.add_runtime_dependency 'kubeclient', '>= 2'
end
