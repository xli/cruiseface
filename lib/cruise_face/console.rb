require 'singleton'
require 'cgi'

module CruiseFace
  class Console
    class UIBuilder
      include Singleton

      def fetch_pipeline_status(pipeline)
        xm = Builder::XmlMarkup.new
        xm.instruct!
        xm.pipeline(:name => pipeline) do
          xm.stages(:type => 'array') do
            CruiseFace.get(pipeline).stages.each do |stage|
              stage.to_xml(xm)
            end
          end
        end
      rescue => e
        xm = Builder::XmlMarkup.new
        xm.instruct!
        xm.errors(:pipeline_name => pipeline) { xm.error(e.message) }
      end

      def to_string(pipeline_status_xml)
        if errors = Hash.from_xml(pipeline_status_xml)['errors']
          return "Could not fetch pipeline #{errors['pipeline_name']} status, got error: #{errors['error']}\n"
        end
        pipeline = Resource.new(ActiveResource::Formats[:xml].decode(pipeline_status_xml))

        status = "#{pipeline.name}:\n"
        pipeline.stages.each do |stage|
          status << " "
          if stage.building_jobs.blank?
            stage_info = "#{truncate(stage.name)}: [#{stage.latest.committers.collect(&:name).join(', ')}]"
            if stage.latest.failed?
              status << ' ' << failing_builds(stage_info)
            else
              status << ' ' << green_builds(stage_info)
            end
          else
            status << spinner << build_running("#{truncate(stage.name)}: #{job_info(stage.building_jobs)} [#{stage.latest.committers.collect(&:name).join(', ')}]")
          end

          unless stage.failing_jobs.blank?
            committers = stage.failing_jobs.collect(&:committers).flatten.collect(&:name).uniq.join(", ")
            status << ', '
            if stage.building_jobs.empty?
              status << failing_builds("#{job_info(stage.failing_jobs)} [#{committers}]")
            else
              building_failed_jobs = stage.building_jobs.collect(&:name) & stage.failing_jobs.collect(&:name)
              status << failing_builds(job_info(stage.failing_jobs))
              status << build_running("(#{job_info(building_failed_jobs)})")
              status << failing_builds(" [#{committers}]")
            end
          end
          status << "\n"
        end
        status
      rescue => e
        status = "Unexpected error: #{e.message}" << "\n"
        status << e.backtrace.join("\n") << "\n"
        status << "\n"
        status << "pipeline status xml:\n"
        status << pipeline_status_xml << "\n"
        status
      end

      def job_info(jobs)
        return name_of(jobs.first) if jobs.size == 1
        return "#{jobs.size} jobs" unless Console.show_details
        return 0 if jobs.empty?
        jobs.collect{|j| name_of(j)}.join(", ")
      end

      def name_of(job)
        job.respond_to?(:name) ? job.name : job
      end

      def truncate(string, width=15)
        if string.length <= width
          string
        else
          string[0, width-3] + "..."
        end
      end

      def spinner
        colorize('5;33m', '*')
      end
      def build_running(text)
        colorize('0;33m', text)
      end
      def failing_builds(text)
        colorize('1;31m', text)
      end
      def green_builds(text)
        colorize('0;32m', text)
      end
      def colorize(color, text)
        "\e[#{color}#{text}\e[0m"
      end

    end

    def self.show_details=(enable)
      ENV['SHOW_CRUISE_DETAILS'] = enable.to_s
    end

    def self.show_details
      ENV['SHOW_CRUISE_DETAILS'] == 'true'
    end

    def initialize(pipeline_names)
      @pipeline_names = pipeline_names
      @mutex = Mutex.new
      @status = {}
    end

    def start
      @pipeline_names.each do |name|
        start_fetch(name)
      end

      puts "Initializing first report"
      loop do
        print '.'
        STDOUT.flush
        sleep 1
        break unless @mutex.synchronize { @status.empty? }
      end
      puts "\nGot first report"
      start_commander

      loop do
        refresh
        sleep 5
      end
    end

    def start_fetch(pipeline)
      Thread.start do
        loop do
          pipeline_status = %x[#{$0} -o -p #{pipeline.inspect}]
          @mutex.synchronize { @status[pipeline] = pipeline_status }
          sleep 10
        end
      end
    end

    def refresh
      status_dump = @mutex.synchronize { @status.dup }.collect do |pipeline, status|
        UIBuilder.instance.to_string(status)
      end.join("\n")
      print %x{clear}
      dashboard = "---- #{Time.now.strftime("%b %d %H:%M:%S")} ----\n"
      dashboard << CGI.unescapeHTML(status_dump) << "\n"
      dashboard << "Type 'open' to open Cruise dashboard" << "\n"
      dashboard << "Type 'show/hide' to show/hide details" << "\n"
      puts dashboard
    end

    def start_commander
      Thread.start do
        loop do
          command = gets.strip
          case command
          when /^(open|start)$/
            if Resource.site.nil?
              puts "ERROR: cruise server url not found"
            else
              system "#{command} #{Resource.site.to_s.inspect}"
            end
          when /^hide$/
            Console.show_details = false;
            refresh
          when /^show$/
            Console.show_details = true;
            refresh
          else
            puts "Unknown command"
          end
        end
      end
    end
  end
end