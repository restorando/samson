# frozen_string_literal: true
class KubernetesPlus::StagesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!
  helper_method :search_service

  def kubernetes_debug
    @stage = current_project.stages.find_by_param(params.require(:id))
    @service_roles = current_project.kubernetes_roles.select(&:service_name)
    @deploy_groups = @stage.deploy_groups
  end

  private

  def search_service(role_pairs)
    kr, kdpgr = role_pairs.find do |kr, _|
      kr.service_name
    end
    KubernetesPlus::NamespacedCluster.build_from_deploy_group(kdpgr).get_service(kr.service_name) if kr
  end

end
