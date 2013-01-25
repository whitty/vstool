#!/ruby/bin/ruby -w

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

require 'test/unit'
require 'vstool'
require 'enumerator'
require 'pp'

class TC_DTE < Test::Unit::TestCase

  def test_connect_to_new
    dte = VsTool::Dte.new
    assert dte
  end

  def test_each_class_has_dte
    assert VsTool::VisualStudio.enum_for(:each_class).find {|x| x.to_s =~ /^DTE2?/}
  end

end
