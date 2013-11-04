class Struct
  def as_json(options = nil)
    Hash[members.zip(values)]
  end
end

