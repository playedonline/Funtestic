module Funtestic
  class Engine < ::Rails::Engine
    initializer "funtestic" do |app|
      ActionController::Base.send :include, Funtestic::Helper
      ActionView::Base.send :include, Funtestic::Helper
    end
  end
end