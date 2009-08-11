require 'rubygems'
require 'daemons'
require 'optparse'

module Delayed
  class Command
    attr_accessor :worker_count, :root_path, :is_rack
    
    def initialize(args)
      @options = {:quiet => true}
      @worker_count = 1
      @is_rack = false
      @root_path = RAILS_ROOT if defined?(RAILS_ROOT)
      
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] start|stop|restart|run"

        opts.on('-h', '--help', 'Show this message') do
          puts opts
          exit 1
        end
        opts.on('-r', '--rack', 'Specifies a rack application') do
          self.root_path = RACK_ROOT
          self.is_rack = true
        end
        opts.on('-l', '--load-path=PATH', 'Specify a custom path (i.e. not rails or rack)') do |p|
          self.root_path = p
        end
        opts.on('-e', '--environment=NAME', 'Specifies the environment to run this delayed jobs under (test/development/production).') do |e|
          is_rack ? ENV['RACK_ENV'] = e : ENV['RAILS_ENV'] = e
        end
        opts.on('--min-priority N', 'Minimum priority of jobs to run.') do |n|
          @options[:min_priority] = n
        end
        opts.on('--max-priority N', 'Maximum priority of jobs to run.') do |n|
          @options[:max_priority] = n
        end
        opts.on('-n', '--number_of_workers=workers', "Number of unique workers to spawn") do |worker_count|
          @worker_count = worker_count.to_i rescue 1
        end
      end
      @args = opts.parse!(args)
    end
  
    def daemonize
      worker_count.times do |worker_index|
        process_name = worker_count == 1 ? "delayed_job" : "delayed_job.#{worker_index}"
        FileUtils.mkdir_p "#{root_path}/tmp/pids"
        Daemons.run_proc(process_name, :dir => "#{root_path}/tmp/pids", :dir_mode => :normal, :ARGV => @args) do |*args|
          run process_name
        end
      end
    end
    
    def run(worker_name = nil)
      Dir.chdir(root_path)
      require File.join(root_path, 'config', 'environment') if ENV['RAILS_ENV']
      
      # Replace the default logger
      logger = Logger.new(File.join(root_path, 'log', 'delayed_job.log'))
      logger.level = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger = logger
      ActiveRecord::Base.clear_active_connections!
      Delayed::Worker.logger = logger
      Delayed::Job.worker_name = "#{worker_name} #{Delayed::Job.worker_name}"
      
      Delayed::Worker.new(@options).start  
    rescue => e
      logger.fatal e
      STDERR.puts e.message
      exit 1
    end
    
  end
end
