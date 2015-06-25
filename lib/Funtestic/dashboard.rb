require 'sinatra/base'
require 'sinatra/cookies'
require 'funtestic'
require 'bigdecimal'
require 'Funtestic/dashboard/helpers'

module Funtestic
  class Dashboard < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views, "#{dir}/dashboard/views"
    set :public_folder, "#{dir}/dashboard/public"
    set :static, true
    set :method_override, true

    helpers Funtestic::DashboardHelpers, Sinatra::Cookies, Funtestic::Helper

    get '/' do
      @experiments = Funtestic::Experiment.all
      erb :index
    end

    get '/enroll/:experiment' do
      if (params[params[:experiment]].present?)
        ab_test params[:experiment]
      else
        ab_user.delete params[:experiment]
      end

      redirect url('/')
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