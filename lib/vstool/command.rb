# (C) Copyright Greg Whiteley 2009-2012
# 
#  This is free software: you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as
#  published by the Free Software Foundation, either version 3 of
#  the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this program.  If not, see <http://www.gnu.org/licenses/>.

module VsTool
  class Command
    def initialize(config)
      @config = config
    end

    PROJECT_ENVIRONMENT = 'VSTOOL_PROJECT'

    def determine_project(project)
      if project.nil? and ENV.member?(PROJECT_ENVIRONMENT) then
        project = ENV[PROJECT_ENVIRONMENT]
        project = project.gsub(/^"(.*)"$/, "\\1")
      end

      project = @config.locate_project if project.nil?
      return nil if project.nil?

      project = project.to_s

      if project =~ /\.exe$/i
        project = Regexp.last_match.pre_match + '.sln'
      end
      
      project = Pathname.new(project)
      if project.relative? then
        project = Pathname.new(".").realpath + project
      end
      return project
    end
    attr_reader :config
  end

  class ProjectCommand < Command
    def initialize(config)
      super(config)
      @project = nil
    end

    def run(project, *args)

      project = determine_project(project)
      puts "project: " + project.inspect if $DEBUG
      raise "Unable to locate project" if project.nil?

      @project = project

      result = self.run_project(*args)
      if result.is_a?(Integer)
        return result
      end
      return nil
    rescue SolutionNotRunning => e
      $stderr.puts e.message
      return -1
    end
    attr_reader :project

  end


  class DteCommand < ProjectCommand
    def initialize(config)
      super(config)
      @dte = nil
    end

    def run_project(*args)

      begin
        dte =  VsTool::Dte.new(@project.to_s)
        if dte
          @dte = dte
        end
      rescue WIN32OLERuntimeError => e
        if self.respond_to?(:dte_error)
          return self.send(:dte_error, e)
        else
          raise
        end
      end

      result = self.run_dte(*args)
      if result.is_a?(Integer)
        return result
      end
      return nil
    end

  end

  class ProcessDteCommand < DteCommand

    def self.match(process_name, cmp)
      Pathname.new(process_name).basename.to_s.casecmp(cmp) == 0
    end

    def run_dte(cmp, *args)
      if cmp.nil?
        $stderr.puts "No process specified"
        return nil
      end

      found = @dte.enum_for(:each_process).find_all do |process|
        ProcessDteCommand.match(process.name, cmp) or process.ProcessId.to_s == cmp.to_s
      end

      if found.length == 0
        $stderr.puts "Failed to find process matching '#{cmp}'"
        return nil
      elsif found.length > 1
        $stderr.puts "Found too many processes matching '#{cmp}:'"
        found.each do |x|
          $stderr.printf("%10s %s\n", x.ProcessId, x.name)
        end
        return nil
      end

      process = found.first
      run_process_dte(process)
    end

  end

end
