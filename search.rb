require 'rubygems'
require 'rest-client'

class Hash
  def slice(keys)
    new_hash = {}
    keys.each do |k|
      val = self[k]
      (new_hash[k] = val) if !val.nil?
    end
    new_hash
  end
end

# NOTE: TODO: when run w/ different limits, I got different answers! 5 more objs showed up w/ limit=100 than w/ limit=50

class FbHelper

  # outputs results in chronologically descending order
  def self.run_query(query_term, opts = {})
    query_params = {limit:100, type:'post'}.merge( opts.slice( %w(type until limit since).map(&:to_sym) ) )
    query_params[:q] = query_term

    results = []
    next_query = "https://graph.facebook.com/search"

    # each query can return a "paging.next" uri, so keep following those until we hit the limit
    while next_query
      begin
        puts "query: #{next_query} w/ params: #{query_params}"
        response = JSON.parse( RestClient.get(next_query, :accept => :json, :params => query_params) )
        data, paging = response['data'], response['paging']
        puts "got #{data.size} data points back!"

        results.concat(data)
        break if !paging
        next_query = paging['next']
        query_params = {} # we don't need this hash anymore. fb's response will take care of the urls from here on out
      rescue Exception => e
        puts "uh oh! #{e}"
        break
      end
    end

    results
  end

  # assumes query terms contain no colons or square brackets
  # assumes results are in chronologically descending order
  def self.save_to_file(results, query_term, type = 'post')
    puts "TODO"
  end

  def self.file_name(latest_timestamp, query_term, type = 'post')
    %("#{query_term}"-#{type}-#{latest_timestamp}.json) # format: "awe.sm"-post-12345123412
  end

  def self.parse_file_name(file_name)
    query, type, timestamp = file_name.split('-')
    return nil if query[0] != '"' || query[-1] != '"'
    query = query[1, query.size-2]
    return query, type, timestamp
  end

end
