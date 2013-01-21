
require 'vstool'

module VsTool
  class DebugCommand < DteCommand
    def run_dte(*args)
      @dte.Debugger.go(false)
    end
  end

  class RunToDebugBreak < DteCommand
    DESIGN_MODE = 1
    BREAK_MODE = 2
    RUN_MODE = 3

    def run_dte(*args)

      consecutive_fail = 0

      first = true
      while (true)
        begin
          sleep(1) if ! first
          first = false

          if consecutive_fail > 60 then
            puts "Waited 60 seconds without a single successful call - abort"
            break
          end

          mode = @dte.Debugger.CurrentMode
          consecutive_fail = 0

          case mode
          when DESIGN_MODE
            puts "Debugger in Design mode - restart it" if $verbose
            @dte.Debugger.go(false)
          when RUN_MODE
            puts "Debugger in Run mode - poll again later" if $debug
            next
          when BREAK_MODE
            puts "Debugger in break mode - done" if $verbose
            break
          end

        rescue OleServerBusy => e
          p e.message if $debug
          consecutive_fail += 1
          next
        rescue WIN32OLERuntimeError => e
          case e.message
          when /Unable to execute method at this time/
          when /Call was rejected by callee/
            consecutive_fail += 1
            next
          else
            raise
          end
        rescue Interrupt
          puts "Ctrl-C pressed - stop waiting"
          break
        end

      end

    end
  end

  class StopCommand < DteCommand
    def run_dte(*args)
      @dte.Debugger.Stop(false)
    end
  end

  class BuildCommand < DteCommand
    def run_dte(*args)
      @dte.build(*args)
    end
  end

  class BuildProjectCommand < DteCommand
    def initialize(config, options = {})
      super(config)
      @both = options[:both]
      @configuration = options[:configuration]
      @wait = !options[:no_wait]
    end

    def run_dte(*projects)
      
      if @both then
        ["Debug", "Release"].each do |config|
          @dte.build_projects(projects, :configuration => config, :wait => true)
        end
      else
        @dte.build_projects(projects, :configuration => @configuration, :wait => @wait)
      end
      return 0
    rescue Dte::ProjectBuildFailed => err
      $stderr.puts err.message
      return err.count
    end
  end


  class ConfigurationCommand < DteCommand
    def run_dte(*args)
      if args.length == 0
        puts @dte.configuration
      else
        @dte.configuration = args.first
      end
    end
  end

  class PopCommand < ProjectCommand

    class ConnectTimeout < VsToolError
    end

    def initialize(config, timeout)
      super(config)
      @timeout = timeout
      @timeout ||= 30.0
    end

    def run_project(*args)
      # DTE not running pop a new one
      target_sln = @project.to_s
      exe_sln = nil
      native_sln = nil

      rot = HAVE_WIN32OLE_ROT ? WIN32OLE::RunningObjectTable.new : nil

      p [target_sln, exe_sln, native_sln] if $debug

      # prefer sln if it exists
      if target_sln =~ /\.exe$/i
        sln = target_sln.gsub(/\.exe$/i, '.sln')
        if File.exists?(sln)
          exe_sln = target_sln
          target_sln = sln.dup
        end
      end
      if target_sln =~ /\.sln$/i
        native_sln = target_sln.dup
      end

      p [target_sln, exe_sln, native_sln] if $debug

      if !rot or !rot.is_running?(target_sln) then

        # try exe if sln doesn't exist
        if !File.exists?(target_sln) then
          sln = target_sln.gsub(/.sln$/i, '.exe')
          if !File.exists?(sln) then
            $stderr.puts "Can't find either #{sln} or #{target_sln} to open"
            return -1
          end
          target_sln = sln.dup
          exe_sln = sln
        end
      end
      p [target_sln, exe_sln, native_sln] if $debug

      if !rot or (!rot.is_running?(target_sln) and !rot.is_running?(native_sln)) then
        cmd = "start devenv.exe \"#{target_sln}\""
        puts cmd.gsub(/^start /, '') if $verbose
        system(cmd)
      end
      # Nothing more to do
      return if args.length == 0

      begin
      Timeout.timeout(@timeout) do
          # from now connections are all to the solution (not the exe)
        while rot and !rot.is_running?(native_sln) do
          puts "#{native_sln} Not running yet" if $debug
          sleep(0.5)
        end

        begin
          puts "Attempt Connect" if $debug
          solution = Dte.new(native_sln)
          break
        rescue WIN32OLERuntimeError => e
          raise e if e =~ /Call was rejected by callee/
          sleep(0.5)
          retry                 # keep trying - timeout will kill us eventually
        end
      end
      rescue Timeout::Error
        puts "Failed to load files:\n  #{args.join("\n  ")}\nafter #{@timeout} seconds"
        return -1
      end

      # Attach ato-abort handlers
      VsTool::AtoAbortCommand.new(self.config).run(@project)
      while file = args.shift do
        VsTool::OpenCommand.new(self.config).run(@project, file)
      end
      if File.exists?(".breakpoints") then
        Pathname(".breakpoints").each_line do |x|
          VsTool::BreakpointCommand.new(self.config).run(@project, x)
        end
      end

    end

  end

  class OpenCommand < DteCommand

    def run_dte(path, *args)
      path = Pathname.new(path)
      if path.exist? then
        @dte.open(path.realpath)
      else
        $stderr.puts "File does not exist: '#{path}'"
      end
    end

  end

  module AbortCommands
    @@breakpoints = ['atoCreateAbortStream_', '_purecall', 'atoQuit_', 'SilAssertionFailed']
    def connect_abort_breakpoints
      @@breakpoints.each do |bp|
        @dte.debugger.Breakpoints.add(bp)
      end
    end
  end

  class AtoErrorCommand < OpenCommand
    include AbortCommands

    def initialize(view, *args)
      super(*args)
      @view = nil
      @view = Pathname.new(view.to_s) unless view.nil?
    end

    ATO_ERROR_PATH = "cerberus/acl/col_/error/atoError_.cpp"

    def run_dte(*args)
      begin
        # use confiuged view if present
        if @view then
          error = @view + ATO_ERROR_PATH
        end
        if error.nil? or !error.exist? then
          # try to determine it
          error = self.config.view_path(ATO_ERROR_PATH)
        end
        super(error.realpath)
      rescue ArgumentError => e
        # handle known exception from view_path (when not in a VOB)
        raise unless e.message =~ /Unable to determine VOB for path/
        $stderr.puts e.message
      end

      self.connect_abort_breakpoints
    end
  end

  class AtoAbortCommand < DteCommand
    include AbortCommands

    def run_dte(*args)
      self.connect_abort_breakpoints
    end
  end

  class BreakpointCommand < DteCommand
    def run_dte(bp, *args)
      @dte.debugger.add_breakpoint(bp)
      nil
    end
  end

  class AttachCommand < ProcessDteCommand

    def run_process_dte(process)
      unless process.IsBeingDebugged
        puts "Attaching to '#{process.Name}'" if $verbose
        process.attach2("native")
        puts "Done" if $verbose
      else
        puts "Already attached to '#{process.Name}'"
      end
    end

  end

  class DetachCommand < ProcessDteCommand

    def run_process_dte(process)
      if process.IsBeingDebugged
        puts "Detaching from '#{process.Name}'" if $verbose
        process.detach
        puts "Done" if $verbose
      else
        puts "Not attached to process '#{process.Name}'"
      end
    end

  end

  class IsOpen < DteCommand
    def run_dte(*args)
      0
    end
  end


end
