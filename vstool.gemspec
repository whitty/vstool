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

$:.push File.expand_path("../lib", __FILE__)
require "vstool/version"


Gem::Specification.new do |s|
  s.name        = "vstool"
  s.version     = VsTool::VERSION
  s.authors     = ["Greg Whiteley"]
  s.email       = ["whitty@users.forge.net"]
  s.homepage    = "https://github.com/whitty/vstool"
  s.summary     = %q{vstool eases creation of tools with sub-commands}
  s.description = %q{vstool eases creation of tools with sub-commands}
  s.license     = "LGPL"

  s.rubyforge_project = "vstool"

  s.add_runtime_dependency 'gw_command'
  s.add_runtime_dependency 'facets', ">=2.0"
  s.add_runtime_dependency 'win32olerot', ">=0.0.2"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", ">= 2.10.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
