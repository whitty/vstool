# (C) Copyright Greg Whiteley 2013
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

# Stubs so I can diagnose some issues without having access to windows
class WIN32OLERuntimeError
end

class WIN32OLE
  class HRESULT
  end

  def initialize(*args)
  end
  
  def self.const_load(*args)
    []
  end
end

class WIN32OLE_TYPE
  def self.ole_classes(*args)
    []
  end
end
