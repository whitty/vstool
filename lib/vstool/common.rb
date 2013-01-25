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
#  License along with this library.  If not, see <http://www.gnu.org/licenses/>.

module VsTool

  class VsToolError < StandardError
  end

  def self.gem_version_match(gem, version)
    gems = Gem::source_index.find_name(gem, version)
    return nil if gem.nil?

    req = Gem::Requirement.new(version)
    return gems.find {|x| req.satisfied_by?(x.version)}
  end

end
