require 'active_support/all'

module Forklift
  class Plan

    def initialize(config={})
      @config      = default_config.merge(config)
      @utils       = Forklift::Base::Utils.new
      @pid         = Forklift::Base::Pid.new(self)
      @logger      = Forklift::Base::Logger.new(self)
      @mailer      = Forklift::Base::Mailer.new(self)
      @connections = {}
    end

    def connections; @connections end
    def config;      @config      end
    def logger;      @logger      end
    def mailer;      @mailer      end
    def utils;       @utils       end
    def pid;         @pid         end

    def connect!
      files = Dir["#{config[:project_root]}/config/connections/**/*.yml"]
      files.each do |f|
        name = f.split("/")[-1].split('.')[0]
        type = f.split("/")[-2]
        connections[type.to_sym] = {} if connections[type.to_sym].nil?
        db_config = utils.load_yml(f)

        begin
          loader = "Forklift::Connection::#{type.camelcase}.new(db_config, self)"
          connection = eval(loader)
          connections[type.to_sym][name.to_sym] = connection
          logger.debug "loaded a #{type.camelcase} connection from #{f}"
        rescue Exception => e
          logger.fatal "cannot create a class type of #{loader} from #{f} | #{e}"
          raise e
        end        
      end
    end

    def do!
      self.logger.log "Starting a forklift ETL"
      # you can use `plan.logger.log` in your plan for logging
      self.pid.safe_to_run?
      self.pid.store!
      # use a pidfile to ensure that only one instance of forklift is running at a time; store the file if OK
      self.connect!
      # this will load all connections in /config/connections/#{type}/#{name}.yml into plan.connections {}
      # this will build all the connection objects (and try to connect in some cases)
      yield
      # your stuff here!
      self.logger.log "Completed a forklift ETL"
      self.pid.delete!
      # remove the pidfile
    end

    private

    def default_config
      return {
        :project_root => Dir.pwd,
        :logger => {
          :debug => false
        },
      }
    end

    #/private

  end
end