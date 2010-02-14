require 'rubygems'
require 'sinatra'
require 'haml'
require 'right_aws'
require 'lib/right_acw_interface'
require 'Base64'

set :views, File.join(File.dirname(__FILE__),'views')

AWS_KEY = ''
AWS_SECRET = ''

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
  
  end
end

@@acw = RightAws::AcwInterface.new(AWS_KEY, AWS_SECRET)

get '/' do
  @metrics = @@acw.list_metrics.group_by{|m| m[:namespace]}
  haml :index
end

get '/metrics/:namespace/:metric' do
  opts = {
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60)
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end

get '/metrics/:namespace/:metric/:range' do
  range = params[:range].to_i
  period = (range * 24 * 60 * 60)/1440
  opts = {
    :period => period,
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60*range),
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end


get '/metrics/:namespace/:metric/:dimention_name/:dimention_value' do
  opts = {
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60),
    :dimentions => {"#{params[:dimention_name]}" => "#{params[:dimention_value]}"}
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end

get '/metrics/:namespace/:metric/:dimention_name/:dimention_value/:range' do
  range = params[:range].to_i
  period = (range * 24 * 60 * 60)/1440
  opts = {
    :period => period,
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60*range),
    :dimentions => {"#{params[:dimention_name]}" => "#{params[:dimention_value]}"}
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end

def get_metrics(opts)
  d = @@acw.get_metric_statistics(opts)
  return d[:datapoints]
end