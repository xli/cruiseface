require 'rubygems'
require 'thread'
require 'active_resource'

module CruiseFace
  class Resource < ActiveResource::Base
    def self.find_pipeline_status
      find(:pipelineStatus)
    end
    def self.find_pipeline_history(name)
      find(:pipelineHistory, :params => {:pipelineName => name})
    end
    def self.find_stage_status(params)
      find(:stageStatus, :params => params)
    end
  end
end
