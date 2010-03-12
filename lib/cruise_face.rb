
require 'cruise_face/resource'
require 'cruise_face/pipeline'
require 'cruise_face/console'

module CruiseFace
  VERSION = '1.0.1'
  extend self

  def site(site)
    Resource.site = site
    Resource.format = :json
    # ignore the collection_name, we'll use action for find cruise resources,
    # for cruise REST API does not fit with ActiveResource
    Resource.collection_name = ''
    self
  end

  def login(username, password)
    Resource.user = username
    Resource.password = password
    self
  end

  def pipelines
    Resource.find_pipeline_status.pipelines.collect(&:name)
  end

  def get(pipeline_name)
    Model::Pipeline.new Resource.find_pipeline_history(pipeline_name)
  end

  def output(pipeline)
    puts Console::UIBuilder.instance.fetch_pipeline_status(pipeline)
  end

  def output_text(pipeline)
    puts Console::UIBuilder.instance.to_string(Console::UIBuilder.instance.fetch_pipeline_status(pipeline))
  end

  def console(pipeline_names)
    Console.new(pipeline_names).start
  end
end
