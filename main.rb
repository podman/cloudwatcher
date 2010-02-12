require 'rubygems'
require 'sinatra'
require 'haml'

set :views, File.join(File.dirname(__FILE__),'views')

class Metric
  def self.all
    @metrics ||= Metric.get_metrics 
  end
  
  def self.get(id)
    Metric.all
    @metric = @metrics[id.to_i-1]
    
    @now = DateTime.now
    if @metric[:data].empty?
      d = `mon-get-stats #{@metric[:name]} --end-time #{@now.to_s} --start-time #{(@now-1).to_s} --period 60 --namespace #{@metric[:namespace]} --statistics "Average" --statistics "Sum" --statistics "Maximum" --statistics "Minimum"`
    else
      d = `mon-get-stats #{@metric[:name]} --end-time #{@now.to_s} --start-time #{(@now-1).to_s} --period 60 --namespace #{@metric[:namespace]} --statistics "Average" --statistics "Sum" --statistics "Maximum" --statistics "Minimum" --dimensions "#{@metric[:data].gsub('{','').gsub('}','')}"`
    end
    
    @data = []
    d.each_line("\n") do |line|
      matches = line.match(/^([-:\d\s]+)\s+([\d.]*)\s*([\d.E-]*)\s*([\d.E-]*)\s*([\d.E-]*)\s*([\d.E-]*)\s*([^\s]*)\s*$/)
      @data.push({
        :date => Time.parse(matches[1]) - 5*60*60,
        :samples => matches[2],
        :average => matches[3],
        :sum => matches[4],
        :maximum => matches[5],
        :minimum => matches[6],
        :unit => matches[7]
      })
    end
    
    return {:metric => @metric, :data => @data}
  
  end
  
  private
  
  def self.get_metrics
    data = `mon-list-metrics`
    results = []
    id = 1
    
    data.each_line("\n") do |line|
      matches = line.match(/^([^\s]*)\s+([^\s]*)\s+([^\s]*)\s*$/)
      results.push({
        :name => matches[1],
        :namespace => matches[2],
        :data => matches[3],
        :id => id
      })
      id += 1
    end
    
    return results
    
  end
end


get '/' do
  @metrics = Metric.all.group_by{|m| m[:namespace]}
  haml :index
end

get '/metrics/:id' do
  d = Metric.get(params[:id])
  @metric = d[:metric]
  @data = d[:data]
  haml :show
end