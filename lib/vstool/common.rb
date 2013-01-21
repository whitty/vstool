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
