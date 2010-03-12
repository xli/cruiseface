$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + './../lib')

require "test/unit"
require "cruise_face"
require 'logger'

ActiveResource::Base.logger = Logger.new(STDOUT)
ActiveResource::Base.logger.level = Logger::ERROR

class CruiseFaceTest < Test::Unit::TestCase
  def setup
    CruiseFace.site('https://cruise01.thoughtworks.com/cruise').login('xli', Base64.decode64(ENV['LDAP_CODE']))
  end

  def test_convert_pipeline_status_xml_to_resource_object
    pipeline_status_xml = CruiseFace::Console::UIBuilder.instance.fetch_pipeline_status('Mingle_trunk--Multiple-Cruise-Test')
    assert CruiseFace::Resource.new(ActiveResource::Formats[:xml].decode(pipeline_status_xml))
  end

  def test_find_all
    CruiseFace.output_text('Installer_Migration_Tests')
    CruiseFace.output_text('Mingle_trunk--Multiple-Cruise-Test')
    CruiseFace.output_text('Mingle_trunk--CentOS5-Oracle10g')
    CruiseFace.output_text('Mingle_trunk--Windows2003-PostgreSQL')
  end

  def test_pipelines
    assert CruiseFace.pipelines
  end
end
