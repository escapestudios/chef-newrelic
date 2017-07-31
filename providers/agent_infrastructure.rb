#
# Cookbook Name:: newrelic
# Provider:: agent_infrastructure
#
# Copyright (c) 2017, David Joos
#

# include helper methods
include NewRelic::Helpers

use_inline_resources if defined?(use_inline_resources)

def whyrun_supported?
  true
end

action :install do
  check_license
  newrelic_repository_infrastructure
  case node['platform_family']
  when 'debian', 'rhel', 'amazon'
    install_newrelic_infrastructure_service_linux
  when 'windows'
    install_newrelic_infrastructure_service_windows
  end
end

def install_newrelic_infrastructure_service_linux
  # install the newrelic infrastructure agent
  package 'newrelic-infra' do
    action new_resource.action
    action new_resource.version unless new_resource.version.nil?
  end

  # workaround for issue on RHEL family version six
  # service is not known to chkconfig
  # dribble the issue by not making use of the RHEL service provider
  service_provider = if node['platform_family'] == 'rhel' && node['platform_version'] =~ /^6/
                       Chef::Provider::Service::Upstart
                     end

  # setup newrelic infrastructure service
  service 'newrelic-infra' do
    provider service_provider unless service_provider.nil?
    action new_resource.service_actions
  end

  # lay down newrelic-infra agent config
  template '/etc/newrelic-infra.yml' do
    cookbook new_resource.template_cookbook
    source new_resource.template_source
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      :resource => new_resource
    )
    notifies :restart, 'service[newrelic-infra]', :delayed
  end
end

def install_newrelic_infrastructure_service_windows
  windows_package 'newrelic-infra' do
    source "https://download.newrelic.com/infrastructure_agent/windows/newrelic-infra.#{new_resource.windows_version}.msi"
    installer_type :msi
    version new_resource.windows_version
    action new_resource.action
    checksum new_resource.windows_checksum
  end

  # lay down newrelic-infra agent config
  template 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml' do
    cookbook new_resource.template_cookbook
    source new_resource.template_source
    variables(
      :resource => new_resource
    )
    notifies :restart, 'service[newrelic-infra]', :delayed
  end

  # setup newrelic-infra service
  service 'newrelic-infra' do
    action new_resource.service_actions
  end
end
