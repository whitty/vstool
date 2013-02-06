# (C) Copyright Greg Whiteley 2008-2013
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

# Local clone of OcraTools
class OcraTools
  def self.ocra_is_compiling?
    defined?(Ocra)
  end
  def self.ocra_is_running?
    ! ENV["OCRA_EXECUTABLE"].nil?
  end
  def self.modify_facets_path
    return unless ocra_is_running?
    return unless facets_path = $:.find {|x| x =~ /[\/\\]facets-([0-9]\.){2}[0-9][\/\\]lib$/ }
    ["core", "more"].each {|x| $: << facets_path + File::SEPARATOR + x}
  end
end
