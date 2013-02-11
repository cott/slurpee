require 'rubygems'
require 'rest-client'
require 'time'
require 'uri'

require './utils'

# NOTE: TODO: when run w/ different limits, I got different answers! 5 more objs showed up w/ limit=100 than w/ limit=50

class FbHelper
  attr_reader :base_dir_name


  def initialize(base_dir_name)
    @base_dir_name = base_dir_name
    Dir.mkdir(base_dir_name) if !Dir.exists?(base_dir_name)
  end


  # THIS IS WHAT YOU SHOULD CARE ABOUT
  # queries: one or more query strings
  def log_search_results(queries, opts = {})
    [*queries].each{|q| run_and_save_query(q, opts)}
  end


  # calls the block (process_result) on each individual result json blob (representing a single post)
  # and returns an enumerable for chaining
  def query_results(query_term, opts = {})

    query_params = {limit:100, type:'post'}.merge( opts.slice( %w(type until limit since).map(&:to_sym) ) )
    query_params[:q] = query_term
    query_suffix = URI.encode(query_params.map{|k,v| "#{k}=#{v}"}.join('&'))

    query_base = "https://graph.facebook.com/search"

    Enumerator.new do |yielder|

      # each query can return a "paging.next" uri, so keep following those until we hit the limit
      while next_query
        begin
          next_query += '&' + query_suffix
          puts "query: #{next_query}"
          response = JSON.parse( RestClient.get(next_query, :accept => :json) )
          data, paging = response['data'], response['paging']
          puts "got #{data.size} data points back!"

          data.each {|result| yielder << result } if data

          break if !paging
          next_query = paging['next']
        rescue Exception => e
          puts "uh oh! #{e}"
          break
        end
      end
    end
  end


  def run_and_save_query(query_string, opts = {})
    # if we have old queries, only reach back until then (unless opts overrides)
    latest_timestamp = self.get_latest_timestamp(query_string)
    opts = {:since => latest_timestamp}.merge(opts) if latest_timestamp && !opts[:since]

    max_timestamp = 0
    num_results = 0

    temp_path = File.join(@base_dir_name, "temp-#{query_string}-#{Time.now.to_i}")
    File.open(temp_path, 'w') do |f|
      query_results(query_string).each do |result|
        num_results += 1
        timestamp = Time.parse(result['created_time']).to_i
        max_timestamp = timestamp if (timestamp > max_timestamp)

        f.write result.to_json
        f.write "\n"
      end
    end
    puts "wrote #{num_results} results to temp file #{temp_path}"
    return if num_results == 0

    new_path = self.move_file(temp_path, query_string, max_timestamp)
    puts "#{temp_path} -> #{new_path}"
  end


  def get_latest_timestamp(query_term)
    dir_name = File.join(@base_dir_name, query_term)
    return nil if !Dir.exists?(dir_name)

    # file names = timestamps, so find the largest file name in the directory
    return Dir.new(dir_name).each.map{|fname| fname.chomp!('.json') }.reject(&:nil?).max
  end


  def move_file(source_file_name, query_term, timestamp)

    # check that the term isn't null/empty or contain a colon (a prohibited char from filenames)
    if !query_term || query_term.size == 0 || query_term[':']
      puts "null/empty/invalid query string. wtffff"
      return
    end

    dir_name = File.join(@base_dir_name, query_term)
    Dir.mkdir(dir_name) if !Dir.exists?(dir_name)

    target_path = File.join(dir_name, "#{timestamp.to_i}.json")
    File.rename(source_file_name, target_path)

    target_path
  end

  def self.split_query_string(str)
    Hash[str.split('&').map{|s| s.split('=')}]
  end

  def self.build_uri(str, params = {})
    return str if params.empty?
    str << '?' if !str['?']
    str << params.to_query
    str
  end
end
