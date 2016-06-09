class Kubernetes::KubernetesJobsController < ApplicationController
  include CurrentProject

  DEPLOYER_ACCESS = [:index, :show].freeze
  before_action :authorize_project_deployer!, only: DEPLOYER_ACCESS
  before_action :authorize_project_admin!, except: DEPLOYER_ACCESS
  before_action :find_task

  def new
    @job = @task.kubernetes_jobs.build
  end

  def create
    Kubernetes::JobService.new(current_user).run!(@task, job_params)

    redirect_to project_kubernetes_task_kubernetes_jobs_path
  end

  def index
    @jobs = @task.kubernetes_jobs.page(params[:page])
  end

  private

  def find_task
    @task = Kubernetes::Task.not_deleted.find(params[:task_id])
  end

  def job_params
    params.require(:kubernetes_job).permit(:stage_id, :commit)
  end
end
