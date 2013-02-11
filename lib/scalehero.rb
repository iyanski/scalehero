require "scalehero/version"
require 'heroku-api'

module Scalehero
  module Scaler
    class << self
      @@heroku = Heroku::API.new(:api_key => ENV['HEROKU_API_KEY'])
      
      def workers
        ps = @@heroku.get_ps(ENV['HEROKU_APP'])
        ps.body.collect{|p| p["process"] if p["process"] =~ /worker\.\d?/}.compact
      end

      def workers=(q)
        @@heroku.post_ps_scale(ENV['HEROKU_APP'], 'worker', q)
      end
      
      def pending_jobs_count
        Resque.info[:pending]
      end
      
      def working_jobs_count
        Resque.info[:working]
      end
      
      def has_one_working_job?
        Resque.info[:working] == 1
      end
    end
  end
  
  def after_perform_scale_down(*args)
    Scaler.workers = 0 if Scaler.workers.count.zero? && Scaler.has_one_working_job?
  end
  
  def after_enqueue_scale_up(*args)
    [
      {:workers => 1,:job_count => 1},
      {:workers => 2,:job_count => 15},
      {:workers => 3,:job_count => 25},
      {:workers => 4,:job_count => 40},
      {:workers => 5,:job_count => 60}
    ].reverse_each do |scale_info|
      if Scaler.pending_jobs_count >= scale_info[:job_count]
        if Scaler.workers.count <= scale_info[:workers]
          Scaler.workers = scale_info[:workers]
        end
        break
      end
    end
  end
end
