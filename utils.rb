# UTILS

class Hash

  # returns the subset of 'self' w/ keys in 'keys'
  def slice(keys)
    keys.each_with_object({}) do |k, hsh|
      (hsh[k] = self[k]) if self.has_key?(k)
    end
  end

  def to_query
    this.map{|k,v| "#{URI.escape(k)}=#{URI.escape(v)}"}.join('&')
  end
end
