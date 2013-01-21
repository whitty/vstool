require 'win32ole'
#require 'win32ole_query'
require 'set'
require 'underscore'
require 'camelcase'

module VsTool

  class OleServerBusy < WIN32OLERuntimeError
  end

  class ComObject
    def initialize(obj)
      @obj = obj
    end

    # should be changed to operate on @obj
    def cast_to(object, typelib, klass)
      object.ole_query_interface(WIN32OLE_TYPE.new(typelib, klass).guid)
    end

    def ole_class
      @obj.ole_obj_help
    end

    def each(*args, &proc)
      @obj.each(*args, &proc)
    end

    def Processes
      pp @obj.methods.sort_by {|x| x.to_s }
      pp @obj.ole_methods.sort_by {|x| x.to_s }
      pp @obj.ole_get_methods.sort_by {|x| x.to_s }
      pp @obj.methods.sort_by {|x| x.to_s }
      pp @obj['Process']
      nil
    end

    def method_missing(method, *args)
      p @obj.ole_methods if $DEBUG

      result = @obj.send(method, *args)
      if result.is_a?(WIN32OLE)
        result = ComObject.new(result)
      end
      return result

    rescue WIN32OLERuntimeError => e
      puts "WIN32OLERuntimeError"
      puts e.message
      if e.message =~ /unknown property or method/ and e.message !~ /Call was rejected by callee/

        # retry in camel-case
        camel = method.to_s.camelcase.to_sym
        if method != camel then
          method = camel
          retry
        end
        raise e, caller
#         super(method, *args)
      elsif e.message =~ /call was rejected by server/ || e.message =~ /Call was rejected by callee/
        raise OleServerBusy.new(e.message), caller
      else
        raise e, caller
      end
    end

  end

# WIN32OLE_TYPE.new('Microsoft Development Environment 8.0', 'Process2')
# WIN32OLE_TYPE.new('Microsoft Development Environment 8.0', 'Process')
# WIN32OLE_TYPE.new('Microsoft Development Environment 8.0', 'Debugger')
# WIN32OLE_TYPE.new('Microsoft Development Environment 8.0', 'Debugger2')
# type.guid

  class Process < ComObject
    @@methods = %w{Name ProcessID Programs DTE Parent Collection}

    def initialize(*args)
      super(*args)
      @obj = cast_to(@obj, 'Microsoft Development Environment 8.0', 'Process2')

      @sig_const = 'VsContextGuidLocals'
      unless Process.const_defined?(@sig_const) then
        WIN32OLE.const_load(@obj, Process)
      end
    end

  end

  class Debugger < ComObject
    def initialize(dte)
      super(dte.Debugger)
      @obj = cast_to(@obj, 'Microsoft Development Environment 8.0', 'Debugger2')
    end

    @@file_line_regex = /^(\S+\.\S+):([0-9]+)$/
    @@function_regex = /^((\w+)?(::\w+))?(\(.*\))?$/

    def add_breakpoint(descriptor, options = {})
      format = options[:format]
      case descriptor
      when @@file_line_regex
        format = :file_line
      when @@function_regex
        format = :function
      end
      raise ArgumentError, "Unable to determine format of '#{descriptor}', and no format specified" if format.nil?

      function = file = line = col = nil
      case format
      when :file_line
        if descriptor =~ @@file_line_regex then
          file, line = Regexp.last_match[1..2]
        else
          file, line = descriptor.split(':')
        end
        line = line.to_i
        col = 1
        function = ""
      when :function
        function = descriptor
      else
        raise ArgumentError, "Unknown file-format '#{format.to_s}'"
      end

      # args are Function, File, Line, Column, Condition, ConditionType, Language, Data, DataCount, Address, HitCount, HitCountType
      # http://msdn.microsoft.com/en-us/library/envdte.breakpoints.add(VS.80).aspx
      args = [function, file, line, col]
      pp args if $debug
      self.Breakpoints.add(*args)
    end
  end

  class VisualStudio
    @@vs80_typelib = 'Microsoft Development Environment 8.0'
    @@vs80_dte_server = 'VisualStudio.DTE.8.0'

    def self.each_class(&block)
      WIN32OLE_TYPE.ole_classes(@@vs80_typelib).each(&block)
    end
  end

  class SolutionNotRunning < VsToolError
    def initialize(path)
      super("Solution '#{path}' is not running")
    end
  end

  class Dte < ComObject

    @@const_loaded = false

    def initialize(path = nil)
      if path.nil?
        super(WIN32OLE.new("VisualStudio.DTE.8.0"))
        @solution = nil
      else
        rot = HAVE_WIN32OLE_ROT ? WIN32OLE::RunningObjectTable.new : nil
        if rot.nil?
          $stderr.puts "Warning: skipping ROT test"
        else
          raise SolutionNotRunning.new(path) unless WIN32OLE::RunningObjectTable.new.is_running?(path)
        end
        @solution = WIN32OLE.connect(path)
        super(@solution.DTE)
      end
      unless @@const_loaded
        begin
          WIN32OLE.const_load(@obj, self.class)
          @@const_loaded = true
        rescue WIN32OLE::HRESULT => e
          p e.message
        end
      end
      @debugger = nil
    end

    def build(options = {})

      active_configuration = @solution.SolutionBuild.ActiveConfiguration.Name
      puts active_configuration

      # check SolutionBuild.BuildState

      if options[:wait] then
        puts "Waiting for build of #'{active_configuration}' to complete"
        @solution.SolutionBuild.build(true)
      else
        @solution.SolutionBuild.build(false)
      end
    end

    def configuration
      @solution.SolutionBuild.ActiveConfiguration.Name
    end

    class NoSuchConfigurationExcepion < ArgumentError
      def initialize(name)
        super("Couldn't find configuration matching #{name}")
      end
    end

    def configuration=(name)
      configs = @solution.SolutionBuild.SolutionConfigurations.enum_for

      if @solution.SolutionBuild.ActiveConfiguration.Name == name
        puts "Configuration #{name} - already selected"
        return
      end

      wanted_config = configs.find do |sol_config|
        sol_config.Name == name
      end
      if wanted_config.nil?
        raise NoSuchConfigurationExcepion.new(name)
      end

      wanted_config.Activate
    end

#     def build
#     end


    def open(path)
      # clean-up pathname to use forward slashes (debugger didn't like it)
      dir, file = Pathname.new(path).split
      path = dir + file.to_s.downcase
      path = Pathname.new(path.to_s.gsub(/\//,'\\'))

      if ! @obj.IsOpenFile(Dte::VsViewKindCode, path.to_s)
        # open it
        begin
          code_window = @obj.OpenFile(Dte::VsViewKindCode, path.to_s)
        rescue
          raise "Failed to open file '#{path}'"
        end
      else
        # try to find window
        pathname = Pathname.new(path).realpath
        # find doc that matches given path
        code_doc = @obj.Documents.enum_for.find do |doc|
          doc_path = Pathname.new(doc.Path + doc.Name)
          if doc_path.exist?
            doc_path.realpath == pathname
          else
            false
          end
        end
        return nil if code_doc.nil?
        code_window = code_doc.Windows.enum_for.find {|x| true }
        return nil if code_window.nil?
      end

      code_window.visible = true # returns true if show is successful
    end

#     # get the Debugger2 interface
#     # don't use this code
#     def dbg
#       dbg = @obj.Debugger
#       dbg2_type = WIN32OLE_TYPE.new('Microsoft Development Environment 8.0', 'Debugger2')
#       dbg2 = dbg.ole_query_interface(dbg2_type.guid)
#       dbg2
#     end

    def each_process
       @obj.Debugger.LocalProcesses.each do |prc|
        yield Process.new(prc)
      end
    end

    def solution
      @solution = @obj.Solution if @solution.nil?
      @solution
    end

    def debugger
#     # get the Debugger2 interface
#     # don't use this code
#     def dbg
#       dbg = @obj.Debugger
#       dbg2_type = WIN32OLE_TYPE.new('Microsoft Development Environment 8.0', 'Debugger2')
#       dbg2 = dbg.ole_query_interface(dbg2_type.guid)
#       dbg2
#     end
      return @debugger unless @debugger.nil?
      @debugger = Debugger.new(@obj)
    end

    def each_project
      @solution.each do |x|
        yield x.Name, x.UniqueName, x
      end
    end

    class ProjectNotFound < ArgumentError
      def initialize(name)
        super("Couldn't find Project matching #{name}")
      end
    end

    class ProjectBuildFailed < RuntimeError
      def initialize(project, count)
        super("Build for Project #{project} failed - #{count} projects errored.")
        @count = count
        @project = project
      end
      attr_reader :count, :project
    end

    def build_projects(project_names, options = {})

      configuration = @solution.SolutionBuild.ActiveConfiguration
      if options[:configuration] then
        name = options[:configuration].to_s

        configs = @solution.SolutionBuild.SolutionConfigurations.enum_for
        wanted_config = configs.find do |sol_config|
          sol_config.Name == name
        end

        if wanted_config.nil?
          raise NoSuchConfigurationExcepion.new(name)
        end
        configuration = wanted_config
      end

      # check SolutionBuild.BuildState

      project_names.each do |proj_name|
        project = @solution.Projects.enum_for.find {|x| x.Name == proj_name}
        raise ProjectNotFound.new(proj_name) if project.nil?

        # no-wait only possible on one project
        if !options[:wait] and project_names.length == 1 then
          @solution.SolutionBuild.BuildProject(configuration, project.UniqueName, false)
          return
        end

        # otherwise all builds are waiting
        puts "Waiting for build of #{proj_name} '#{configuration.Name}' to complete"
        @solution.SolutionBuild.BuildProject(configuration, project.UniqueName, true)
        failCount = @solution.SolutionBuild.LastBuildInfo
        raise ProjectBuildFailed.new(proj_name, failCount) unless failCount == 0
      end
    end


  end

end

# #   vs_solution = WIN32OLE.connect(project)
# #   dte = vs_solution.DTE
# # #   pp dte.ole_methods
# # #   pp dte.methods

#   debugger = dte.Debugger

#   debugger.go(false)
