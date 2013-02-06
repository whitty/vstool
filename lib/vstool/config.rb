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

require 'yaml'
require 'enumerator'

begin
  require 'clearcase/pathname'
rescue LoadError
  module Clearcase
    def self.available?
      false
    end
  end
end

require 'pp'

module VsTool

  class Config

    def initialize(conf_file_path = nil)
      if conf_file_path.nil?
        pathname = ENV["HOME"] || ""
        conf_file_path = Pathname.new(pathname) + ".vstool.yaml"
      else
        conf_file_path = Pathname.new(conf_file_path) unless conf_file_path.is_a?(Pathname)
      end

      unless conf_file_path.exist? then
        File.open(conf_file_path, "w") do |file|
          YAML.dump(@@default_config, file)
        end
      end
      @file = conf_file_path
      @data = YAML.load_file(@file)
    end

    @@default_config = {
      'directories' => {
        '/ipmodel/host/...' => '/ipmodel/host/system/sessions/RouterTester900/RouterTester900.sln',
        '/ipview/ipgui/...' => '/ipview/ipgui/WinApp/RT900Controls/RT900Controls.sln',
        '/ipview/rt900gui/...' => '/ipview/rt900gui/Rt900Gui.sln',
      },
      'executable_extensions' => '\\.exe$'
    }

    def decode_spec(path)
      absolute = false
      continuation = false
      if path =~ /^\// then
        absolute = true
        path = Regexp.last_match.post_match
      end
      if path =~ /\.\.\.$/ then
        continuation = true
        path = Regexp.last_match.pre_match
      end
      return path, absolute, continuation
    end

    def match(spec, wd, vob, view)
      path, absolute, continuation = spec

      test_path = if absolute then
                    view + path
                  else
                    wd + path
                  end

      # - no match if base-directory (continuation) or final path doesn't exist
      return false unless test_path.exist?

      test_path = test_path.realpath

      if continuation then
        in_tree = ! wd.relative_path_from(test_path).enum_for(:each_filename).find do |x|
          x == ".."
        end
        in_tree
      else
        # match if wd == test-path
        test_path == wd.realpath
      end
    end

    def locate_project(cwd = nil)
      begin
      wd, vob, view = fetch_view_details(cwd)
      rescue ArgumentError => e
        raise unless e.message =~ /Unable to determine VOB for path/
        # review - assume view-like structure in lieu of clearcase
        wd = Pathname.getwd
        view = wd.enum_for(:descend).first
        vob = nil
        $stderr.puts "Warning: assuming '#{view}' is the current \"view\""
      end
      pp [wd, vob, view] if $debug

      dirs = @data['directories']
      found = dirs.each do | match, soln |
        spec = decode_spec(match)
        if match(spec, wd, vob, view) then
          ignore, absolute, ignore = spec
          if absolute then
            return view + soln[1..-1]
          else
            return soln
          end
        end
      end

      nil
    end

    def view_path(path)
      wd, vob, view = fetch_view_details(nil)
      view + path
    end

    def fetch_view_details(cwd = nil)
      raise ArgumentError, "Unable to determine VOB for path #{cwd}" unless Clearcase.available?

      cwd ||= ClearcasePathname.new(".")
      unless cwd.nil?
        cwd = ClearcasePathname.new(cwd) unless cwd.is_a?(ClearcasePathname)
      end

      cwd = cwd.realpath
      vob = cwd.vob
      raise ArgumentError, "Unable to determine VOB for path #{cwd}" if vob.nil?
      vob = vob.realpath
      view = vob.parent.realpath
      [cwd, vob, view]
    end

  end                           # Config

end
