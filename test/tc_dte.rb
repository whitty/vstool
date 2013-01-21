#!/ruby/bin/ruby -w

require 'test/unit'
require 'dte.rb'
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
