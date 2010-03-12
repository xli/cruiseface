$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + './../lib')

require "test/unit"
require "cruise_face"
require 'logger'
require 'active_resource/http_mock'

ActiveResource::Base.logger = Logger.new(STDOUT)
ActiveResource::Base.logger.level = Logger::ERROR
