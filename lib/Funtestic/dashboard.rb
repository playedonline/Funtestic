require 'sinatra/base'
require 'funtestic'
require 'bigdecimal'
require 'funtestic/dashboard/helpers'

module Funtestic
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/dashboard/views"
    set :public_folder, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true

    helpers Funtestic::DashboardHelpers

    get '/' do
      @experiments = Funtestic::Experiment.all
      erb :index
    end

    post '/:experiment' do
      @experiment = Funtestic::Experiment.find(params[:experiment])
      @alternative = Funtestic::Alternative.new(params[:alternative], params[:experiment])
      @experiment.winner = @alternative.name
      redirect url('/')
    end

    post '/reset/:experiment' do
      @experiment = Funtestic::Experiment.find(params[:experiment])
      @experiment.reset
      redirect url('/')
    end

    delete '/:experiment' do
      @experiment = Funtestic::Experiment.find(params[:experiment])
      @experiment.delete
      redirect url('/')
    end
  end
end