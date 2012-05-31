require 'logger'
require 'pty'
require 'forwardable'
require 'stringio'
require 'shellwords'
require 'rbconfig'
require 'strscan'

# A better expect.rb
#
# Implementation note: because of the way PTY is implemented in Ruby, it is
# possible when executing a quick non-interactive command for PTY::ChildExited
# to be raised before ever getting input/output handles to the child
# process. Without an output handle, it's not possible to read any output the
# process produced. This is obviously undesirable, especially since when a
# command is unexpectedly quick and noninteractive it's usually because there
# was an error and you really want to be able to see what the problem was.
#
# Greenletters' solution to this problem is to wrap every command in a short
# script. The script executes the passed command and on termination, outputs an
# easily recognizable marker string. Then it waits for acknowledgment (a
# newline) before exiting. When Greenletters sees the marker string in the
# output, it automatically performs the acknowledgement and allows the child
# process to finish. By forcing the child process to wait for acknowledgement,
# we guarantee that the child will never exit before we have a chance to look at
# the output.
module Greenletters

  # :stopdoc:
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
  # :startdoc:

  # Returns the version string for the library.
  #
  def self.version
    @version ||= File.read(path('version.txt')).strip
  end

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args, &block )
    rv =  args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
    if block
      begin
        $LOAD_PATH.unshift LIBPATH
        rv = block.call
      ensure
        $LOAD_PATH.shift
      end
    end
    return rv
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args, &block )
    rv = args.empty? ? PATH : ::File.join(PATH, args.flatten)
    if block
      begin
        $LOAD_PATH.unshift PATH
        rv = block.call
      ensure
        $LOAD_PATH.shift
      end
    end
    return rv
  end

  # Utility method used to require all files ending in .rb that lie in the
  # directory below this file that has the same name as the filename passed
  # in. Optionally, a specific _directory_ name can be passed in such that
  # the _filename_ does not have to be equivalent to the directory.
  #
  def self.require_all_libs_relative_to( fname, dir = nil )
    dir ||= ::File.basename(fname, '.*')
    search_me = ::File.expand_path(
        ::File.join(::File.dirname(fname), dir, '**', '*.rb'))

    Dir.glob(search_me).reject{|fn| fn =~ /cucumber_steps.rb$/}.sort.each {|rb| require rb}
  end

  LogicError   = Class.new(::Exception)
  SystemError  = Class.new(RuntimeError)
  TimeoutError = Class.new(SystemError)
  ClientError  = Class.new(RuntimeError)
  StateError   = Class.new(ClientError)

  # This class offers a pass-through << operator and saves the most recent 256
  # bytes which have passed through.
  class TranscriptHistoryBuffer
    attr_reader :buffer

    def initialize(transcript)
      @buffer     = String.new
      @transcript = transcript
    end

    def <<(output)
      @buffer     << output
      @transcript << output
      length = [@buffer.length, 256].min
      @buffer = @buffer[-length, length]
      self
    end
  end

  def Trigger(event, *args, &block)
    klass = trigger_class_for_event(event)
    klass.new(*args, &block)
  end

  def trigger_class_for_event(event)
    ::Greenletters.const_get("#{event.to_s.capitalize}Trigger")
  end

  class Trigger
    attr_accessor :time_to_live
    attr_accessor :exclusive
    attr_accessor :logger
    attr_accessor :interruption
    attr_reader   :options

    alias_method :exclusive?, :exclusive

    def initialize(options={}, &block)
      @block        = block || lambda{}
      @exclusive    = options.fetch(:exclusive) { false }
      @logger       = ::Logger.new($stdout)
      @interruption = :none
      @options      = options
    end

    def call(process)
      @block.call(process)
      true
    end
  end

  class OutputTrigger < Trigger
    def initialize(pattern=//, options={}, &block)
      super(options, &block)
      options[:operation] ||= :all
      @pattern = pattern
    end

    def to_s
      "output matching #{@pattern.inspect}"
    end

    def call(process)
      case @pattern
      when Array then match_multiple(process)
      else match_one(process)
      end
    end

    def match_one(process)
      scanner = process.output_buffer
      @logger.debug "matching #{@pattern.inspect} against #{scanner.rest.inspect}"
      if scanner.scan_until(@pattern)
        @logger.debug "matched #{@pattern.inspect}"
        @block.call(process, scanner)
        true
      else
        false
      end
    end

    def match_multiple(process)
      op = options[:operation]
      raise "Invalid operation #{op.inspect}" unless [:any, :all].include?(op)
      scanner = process.output_buffer
      @logger.debug "matching #{op} of multiple patterns against #{scanner.rest.inspect}"
      starting_pos = scanner.pos
      ending_pos   = starting_pos
      result = @pattern.send("#{op}?") {|pattern|
        scanner.pos = starting_pos
        if (char_count = scanner.skip_until(pattern))
          ending_pos = [ending_pos, starting_pos + char_count].max
        end
      }
      if result
        scanner.pos = ending_pos
        true
      else
        scanner.pos = starting_pos
        false
      end
    end
  end

  class BytesTrigger < Trigger
    attr_reader :num_bytes

    def initialize(num_bytes, options={}, &block)
      super(options, &block)
      @num_bytes = num_bytes
    end

    def to_s
      "#{num_bytes} bytes of output"
    end

    def call(process)
      @logger.debug "checking if #{num_bytes} byes have been received"
      process.rest_size >= num_bytes
    end
  end

  class TimeoutTrigger < Trigger
    attr_reader :expiration_time

    def initialize(expiration_time=Time.now+1.0, options={}, &block)
      super(options, &block)
      @expiration_time = case expiration_time
                         when Time then expiration_time
                         when Numeric then Time.now + expiration_time
                         end
    end

    def to_s
      "timeout at #{expiration_time}"
    end

    def call(process)
      @block.call(process, process.blocker)
      process.time >= expiration_time
    end
  end

  class ExitTrigger < Trigger
    attr_reader :pattern

    def initialize(pattern=0, options={}, &block)
      super(options, &block)
      @pattern = pattern
    end

    def call(process)
      if process.status && pattern === process.status.exitstatus
        @block.call(process, process.status)
        true
      else
        false
      end
    end

    def to_s
      "exit with status #{pattern}"
    end
  end

  class UnsatisfiedTrigger < Trigger
    def to_s
      "unsatisfied wait"
    end

    def call(process)
      @block.call(process, process.interruption, process.blocker)
      true
    end
  end

  class Process
    END_MARKER        = '__GREENLETTERS_PROCESS_ENDED__'
    DEFAULT_LOG_LEVEL = ::Logger::WARN

    # Shamelessly stolen from Rake
    RUBY_EXT =
      ((Config::CONFIG['ruby_install_name'] =~ /\.(com|cmd|exe|bat|rb|sh)$/) ?
      "" :
      Config::CONFIG['EXEEXT'])
    RUBY       = File.join(
      Config::CONFIG['bindir'],
      Config::CONFIG['ruby_install_name'] + RUBY_EXT).
      sub(/.*\s.*/m, '"\&"')

    extend Forwardable
    include ::Greenletters

    attr_reader   :command      # Command to run in a subshell
    attr_accessor :blocker      # The Trigger currently being waited for, if any
    attr_reader   :input_buffer # Input waiting to be written to process
    attr_reader   :output_buffer # Output ready to be read from process
    attr_reader   :status        # :not_started -> :running -> :ended -> :exited
    attr_reader   :cwd          # Working directory for the command

    def_delegators :input_buffer, :puts, :write, :print, :printf, :<<
    def_delegators :output_buffer, :rest, :rest_size, :check_until
    def_delegators  :blocker, :interruption, :interruption=

    def initialize(*args)
      options         = if args.last.is_a?(Hash) then args.pop else {} end
      @command        = args
      @triggers       = []
      @blocker        = nil
      @input_buffer   = StringIO.new
      @output_buffer  = StringScanner.new("")
      @env            = options.fetch(:env) {{}}
      @cwd            = options.fetch(:cwd) {Dir.pwd}
      @logger   = options.fetch(:logger) {
        l = ::Logger.new($stdout)
        l.level = DEFAULT_LOG_LEVEL
        l
      }
      @state         = :not_started
      @shell         = options.fetch(:shell) { '/bin/sh' }
      @transcript    = options.fetch(:transcript) {
        t = Object.new
        def t.<<(*)
          # NOOP
        end
        t
      }
      @history = TranscriptHistoryBuffer.new(@transcript)
    end

    def on(event, *args, &block)
      t = add_nonblocking_trigger(event, *args, &block)
    end

    def wait_for(event, *args, &block)
      raise "Already waiting for #{blocker}" if blocker
      t = add_blocking_trigger(event, *args, &block)
      process_events
    rescue
      unblock!
      triggers.delete(t)
      raise
    end

    def add_nonblocking_trigger(event, *args, &block)
      t = add_trigger(event, *args, &block)
      catchup_trigger!(t)
      t
    end

    def add_trigger(event, *args, &block)
      t = Trigger(event, *args, &block)
      t.logger = @logger
      triggers << t
      @logger.debug "added trigger on #{t}"
      t
    end

    def prepend_trigger(event, *args, &block)
      t = Trigger(event, *args, &block)
      t.logger = @logger
      triggers.unshift(t)
      @logger.debug "prepended trigger on #{t}"
      t
    end


    def add_blocking_trigger(event, *args, &block)
      t = add_trigger(event, *args, &block)
      t.time_to_live = 1
      @logger.debug "waiting for #{t}"
      self.blocker = t
      catchup_trigger!(t)
      t
    end

    def start!
      raise StateError, "Already started!" unless not_started?
      @logger.debug "installing end marker handler for #{END_MARKER}"
      prepend_trigger(:output, /#{END_MARKER}/, :exclusive => false, :time_to_live => 1) do |process, data|
        handle_end_marker
      end
      handle_child_exit do
        cmd = wrapped_command
        @logger.debug "executing #{cmd.join(' ')}"
        merge_environment(@env) do
          @logger.debug "command environment:\n#{ENV.inspect}"
          @output, @input, @pid = PTY.spawn(*cmd)
        end
        @state = :running
        @logger.debug "spawned pid #{@pid}"
      end
    end

    def flush_output_buffer!
      @logger.debug "flushing output buffer"
      @output_buffer.terminate
    end

    def alive?
      ::Process.kill(0, @pid)
      true
    rescue Errno::ESRCH, Errno::ENOENT
      false
    end

    def blocked?
      @blocker
    end

    def running?
      @state == :running
    end

    def not_started?
      @state == :not_started
    end

    def exited?
      @state == :exited
    end

    # Have we seen the end marker yet?
    def ended?
      @state == :ended
    end

    def time
      Time.now
    end

    private

    attr_reader :triggers

    def wrapped_command
      [RUBY,
        '-C', cwd,
        '-e', "system(*#{command.inspect})",
        '-e', "puts(#{END_MARKER.inspect})",
        '-e', "gets",
        '-e', "exit $?.exitstatus"
      ]
    end

    def process_events
      raise StateError, "Process not started!" if not_started?
      handle_child_exit do
        while blocked?
          @logger.debug "select()"
          input_handles  = input_buffer.string.empty? ? [] : [@input]
          output_handles = [@output]
          error_handles  = [@input, @output]
          timeout        = shortest_timeout
          @logger.debug "select() on #{[output_handles, input_handles, error_handles, timeout].inspect}"
          ready_handles = IO.select(
            output_handles, input_handles, error_handles, timeout)
          if ready_handles.nil?
            process_timeout
          else
            ready_outputs, ready_inputs, ready_errors = *ready_handles
            ready_errors.each do |handle| process_error(handle) end
            ready_outputs.each do |handle| process_output(handle) end
            ready_inputs.each do |handle| process_input(handle) end
          end
        end
      end
    end

    def process_input(handle)
      @logger.debug "input ready #{handle.inspect}"
      handle.write(input_buffer.string)
      @logger.debug format_output_for_log(input_buffer.string)
      @logger.debug "wrote #{input_buffer.string.size} bytes"
      input_buffer.string = ""
    end

    def process_output(handle)
      @logger.debug "output ready #{handle.inspect}"
      data = handle.readpartial(1024)
      output_buffer << data
      @history << data
      @logger.debug format_input_for_log(data)
      @logger.debug "read #{data.size} bytes"
      handle_triggers(:bytes)
      handle_triggers(:output)
      flush_triggers!(OutputTrigger) if ended?
      flush_triggers!(BytesTrigger) if ended?
      # flush_output_buffer! unless ended?
    end

    def collect_remaining_output
      if @output.nil?
        @logger.debug "unable to collect output for missing output handle"
        return
      end
      @logger.debug "collecting remaining output"
      while data = @output.read_nonblock(1024)
        output_buffer << data
        @logger.debug "read #{data.size} bytes"
      end
    rescue EOFError, Errno::EIO => error
      @logger.debug error.message
    end

    def wait_for_child_to_die
      # Soon we should get a PTY::ChildExited
      while running? || ended?
        @logger.debug "waiting for child #{@pid} to die"
        sleep 0.1
      end
    end

    def process_error(handle)
      @logger.debug "error on #{handle.inspect}"
      raise NotImplementedError, "process_error()"
    end

    def process_timeout
      @logger.debug "timeout"
      handle_triggers(:timeout)
      process_interruption(:timeout)
    end

    def handle_exit(status=status_from_waitpid)
      return false if exited?
      @logger.debug "handling exit of process #{@pid}"
      @state  = :exited
      @status = status
      handle_triggers(:exit)
      if status == 0
        process_interruption(:exit)
      else
        process_interruption(:abnormal_exit)
      end
    end

    def status_from_waitpid
      @logger.debug "waiting for exist status of #{@pid}"
      ::Process.waitpid2(@pid)[1]
    end

    def handle_triggers(event)
      klass = trigger_class_for_event(event)
      matches = 0
      triggers.grep(klass).each do |t|
        @logger.debug "checking #{event} against #{t}"
        check_trigger(t) do
          matches += 1
          break if t.exclusive?
        end
      end
      matches > 0
    end

    def check_trigger(trigger)
      if trigger.call(self)         # match
        @logger.debug "match trigger #{trigger}"
        if blocker.equal?(trigger)
          unblock!
        end
        if trigger.time_to_live
          if trigger.time_to_live > 1
            trigger.time_to_live -= 1
            @logger.debug "trigger ttl reduced to #{trigger.time_to_live}"
          else
            triggers.delete(trigger)
            @logger.debug "trigger removed"
          end
        end
        yield if block_given?
      else
        @logger.debug "no match"
      end
    end

    def handle_end_marker
      return false if ended?
      @logger.debug "end marker found"
      output_buffer.string.gsub!(/#{END_MARKER}\s*/, '')
      output_buffer.unscan
      @state = :ended
      @logger.debug "end marker expunged from output buffer"
      @logger.debug "acknowledging end marker"
      self.puts
    end

    def unblock!
      @logger.debug "unblocked"
      triggers.delete(@blocker)
      @blocker = nil
    end

    def handle_child_exit
      handle_eio do
        yield
      end
    rescue PTY::ChildExited => error
      @logger.debug "caught PTY::ChildExited"
      collect_remaining_output
      handle_exit(error.status)
    end

    def handle_eio
      yield
    rescue Errno::EIO => error
      @logger.debug "Errno::EIO caught"
      wait_for_child_to_die
    end

    def flush_triggers!(kind)
      @logger.debug "flushing triggers matching #{kind}"
      triggers.delete_if{|t| kind === t}
    end

    def merge_environment(new_env)
      old_env = new_env.inject({}) do |old, (key, value)|
        old[key] = ENV[key]
        ENV[key] = value
        old
      end
      yield
    ensure
      old_env.each_pair do |key, value|
        if value.nil? then ENV.delete(key) else ENV[key] = value end
      end
    end

    def process_interruption(reason)
      if blocked?
        self.interruption = reason
        unless handle_triggers(:unsatisfied)
          raise SystemError,
                "Interrupted (#{reason}) while waiting for #{blocker}.\n" \
                "Recent activity:\n" +
                @history.buffer
        end
        unblock!
      end
    end

    def catchup_trigger!(trigger)
      check_trigger(trigger)
    end

    def format_output_for_log(text)
      "\n" + text.split("\n").map{|l| ">> #{l}"}.join("\n")
    end

    def format_input_for_log(text)
      "\n" + text.split("\n").map{|l| "<< #{l}"}.join("\n")
    end

    def shortest_timeout
      result = triggers.grep(TimeoutTrigger).map{|t|
        t.expiration_time - Time.now
      }.min
      if result.nil? then result = 1.0 end
      if result < 0 then result = 0 end
      result
    end
  end
end

Greenletters.require_all_libs_relative_to(__FILE__)

