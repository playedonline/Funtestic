module Funtestic
  class Engine < ::Rails::Engine
    initializer "funtestic" do |app|
      ActionController::Base.send :include, Funtestic::Helper
      ActionController::Base.helper Funtestic::Helper
    end
  end
end