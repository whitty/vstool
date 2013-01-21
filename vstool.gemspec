$:.push File.expand_path("../lib", __FILE__)
require "vstool/version"

Gem::Specification.new do |s|
  s.name        = "vstool"
  s.version     = VsTool::VERSION
  s.authors     = ["Greg Whiteley"]
  s.email       = ["whitty@users.sourceforge.net"]
  s.homepage    = "https://github.com/whitty/vstool"
  s.summary     = %q{vstool eases creation of tools with sub-commands}
  s.description = %q{vstool eases creation of tools with sub-commands}
  s.license     = "LGPL"

  s.rubyforge_project = "vstool"

  s.add_runtime_dependency = 'gw_command'
  s.add_runtime_dependency = 'win32ole'
  s.add_runtime_dependency = 'win32olerot', ">=0.0.2"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", ">= 2.10.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
