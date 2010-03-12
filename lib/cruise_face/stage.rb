require 'ostruct'
require 'builder'

module CruiseFace::Model
  class Stage

    # History of a Stage cares about completed jobs, which maybe inside a running Stage
    class History
      def initialize(stages)
        @stages = stages
      end

      def first
        @stages.first
      end

      def passed?
        as_jobs.all?(&:passed?)
      end
      def failed?
        !passed?
      end

      def status
        passed? ? 'Passed' : 'Failed'
      end

      def failed_jobs_from_now_until_passed(job_name)
        jobs = []
        @stages.each do |stage|
          if job = stage.jobs.select(&:completed?).detect {|job| job.name == job_name}
            if job.failed?
              jobs << job
            else
              break
            end
          end
        end
        jobs
      end

      # A History of Stage could transform to a group of jobs, which is containing latest
      # completed status in a Job's history.
      # In some cases, the job may not have completed status, then the running/canceled job
      # would be included in the return jobs
      def as_jobs
        @jobs ||= find_latest_completed_jobs
      end

      private
      def find_latest_completed_jobs
        return [] if first.nil?

        latest_completed_jobs = []
        @stages.each do |stage|
          latest_completed_jobs = stage.jobs.collect do |job|
            latest_completed_jobs.select(&:completed?).detect{|j| j.name == job.name} || job
          end
          if latest_completed_jobs.all?(&:completed?)
            break
          end
        end

        latest_completed_jobs
      end
    end

    attr_reader :history

    def initialize(config, pipelines)
      @config = config
      @history = History.new(pipelines.collect { |pipeline| pipeline.stages[name] }.reject {|history_stage| history_stage.unknown? })
    end

    def name
      @config.name
    end

    def manual?
      @config.isAutoApproved == 'false'
    end

    def building?
      return false if no_history?
      @history.first.building?
    end

    def building_jobs
      return [] if no_history?
      @history.first.jobs.select(&:incompleted?)
    end

    def latest_committers
      return ['Unknown'] if no_history?
      @history.first.committers
    end

    def no_history?
      @history.first.blank?
    end

    def to_xml(xm)
      xm.stage(:name => self.name) do
        xm.latest(:status => self.history.status) do
          xm.failed(self.history.failed?, :type => 'boolean')
          xm.committers(:type => 'array') do
            self.latest_committers.each { |committer| xm.committer(:name => committer) }
          end
        end
        xm.building_jobs(:type => 'array') do
          self.building_jobs.each { |job| xm.job(:name => job.name) }
        end
        xm.failing_jobs(:type => 'array') do
          self.history.as_jobs.select(&:failed?).each do |job|
            xm.job(:name => job.name) do
              xm.committers(:type => 'array') { find_broking_builds_committers(job).each { |committer| xm.committer(:name => committer) } }
            end
          end
        end
      end
    end

    def find_broking_builds_committers(failed_job)
      broken_jobs = []
      self.history.failed_jobs_from_now_until_passed(failed_job.name).each do |job|
        if job.failed?
          broken_jobs << job
        else
          break
        end
      end
      broken_jobs.collect(&:stage).collect(&:committers).flatten.uniq
    end

    # from 0 to 100, as 0% to 100%
    # when 1 building job
    # => (building job current_build_duration/last_build_duration) * 100
    # when 2 building job
    #   time left = [(job2.last_build_duration - job2.current_build_duration), (job1.last_build_duration - job1.current_build_duration)].max
    #   time built = [job2.current_build_duration, job1.current_build_duration].max
    # => (time left / (time left + time built)) * 100
    # when 1 building job1, 1 scheduled job2
    #   time left = job2.last_build_duration + (job1.last_build_duration - job1.current_build_duration)
    #   time built = job1.current_build_duration
    # => (time left / (time left + time built)) * 100
    # when 0 building job, 1 scheduled job
    # => 0
    # when 0 building job, 1 completed job1, 1 scheduled job2
    #   time left = job2.last_build_duration
    #   time built = job1.current_build_duration
    # => (time left / (time left + time built)) * 100
    # when 0 building job, 2 completed job1 & job2, 1 scheduled job3
    #   time left = job3.last_build_duration
    #   time built = job1.current_build_duration + job2.current_build_duration
    # => (time left / (time left + time built)) * 100
    # when 1 building job0, 2 completed job1 & job2, 1 scheduled job3
    #   time left = job3.last_build_duration + (job0.last_build_duration - job0.current_build_duration)
    #   time built = job1.current_build_duration + job2.current_build_duration + job0.current_build_duration
    # => (time left / (time left + time built)) * 100
    def progress
      return 100 unless @history.first
      completed_size = @history.first.jobs.select(&:completed?).size
      completed_size * 100 / @history.first.jobs.size
    end
  end
end
