require 'cruise_face/stage'

module CruiseFace::Model
  class Pipeline
    PASSED_STATUS = 'Passed'
    FAILED_STATUS = 'Failed'
    CANCELED_STATUS = 'Cancelled'
    COMPLETED_STATUS = [PASSED_STATUS, FAILED_STATUS, CANCELED_STATUS]
    BUILDING_STATUS = 'Building'
    UNKNOWN_STATUS = 'Unknown'

    class History
      class Pipeline
        attr_reader :resource, :name, :label
        def initialize(name, resource)
          @name = name
          @resource = resource
          @label = @resource.label
        end

        def stages
          @stages || init_stages
        end

        def committers
          @resource.materialRevisions.first.modifications.collect(&:user).uniq
        end

        def find_jobs(stage)
          find_stage_status(stage).stage.builds.collect { |build| Job.new stage, build }
        end

        def find_stage_status(stage)
          params = {:pipelineName => @name, :label => @label, :stageName => stage.name, :counter => stage.counter}
          CruiseFace::Resource.find_stage_status(params)
        end

        def to_s
          "pipeline[#{@name}<#{@label}>]"
        end

        private
        def init_stages
          @stages = {}
          @resource.stages.each do |stage_resource|
            stage = Stage.new(self, stage_resource)
            @stages[stage.name] = stage
          end
          @stages
        end
      end

      class Stage
        attr_reader :resource
        def initialize(pipeline, resource)
          @pipeline = pipeline
          @resource = resource
        end

        def committers
          @pipeline.committers
        end

        def completed?
          !building?
        end

        def unknown?
          UNKNOWN_STATUS == @resource.stageStatus
        end

        # the stageStatus maybe 'Failed' when there is one job failed and others are still building
        def building?
          jobs.any? {|job| job.incompleted?}
        end

        def name
          @resource.stageName
        end

        def counter
          @resource.stageCounter
        end

        def to_s
          "#{name}<#{counter}>[#{@pipeline}]"
        end
        
        def jobs
          @jobs ||= @pipeline.find_jobs(self)
        end
      end

      class Job
        attr_reader :stage

        def initialize(stage, resource)
          @stage = stage
          @resource = resource
        end

        def name
          @resource.name
        end

        def passed?
          @resource.result == PASSED_STATUS
        end

        def failed?
          [FAILED_STATUS, CANCELED_STATUS].include? @resource.result
        end

        def completed?
          @resource.is_completed == 'true'
        end

        def incompleted?
          !completed?
        end

        def last_build_duration
          @resource.last_build_duration
        end

        def current_build_duration
          @resource.current_build_duration
        end

        def to_s
          "Job #{name}[#{@stage}] #{completed? ? 'completed' : ''} #{failed? ? "failed" : (passed? ? 'passed' : 'unknown')}"
        end
      end

      def initialize(pipelines)
        @pipelines = pipelines
      end

      def each(&block)
        @pipelines.each(&block)
      end

      def collect(&block)
        @pipelines.collect(&block)
      end
    end

    attr_reader :name, :resource
    def initialize(resource)
      @resource = resource
      @name = resource.pipelineName
      @pipeline = resource.groups.first
    end

    def stages
      @pipeline.config.stages.collect do |stage|
        Stage.new(stage, history)
      end
    end

    def history
      History.new(@pipeline.history.collect { | pipeline | History::Pipeline.new(self.name, pipeline) })
    end
  end
end
