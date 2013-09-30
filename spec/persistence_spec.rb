require_relative "spec_helper"

describe Funtestic::Persistence do

  subject { Funtestic::Persistence }

  describe ".adapter" do
    context "when the persistence config is a symbol" do
      it "should return the appropriate adapter for the symbol" do
        Funtestic.configuration.stub(:persistence).and_return(:cookie)
        subject.adapter.should eq(Funtestic::Persistence::CookieAdapter)
      end

      it "should return an adapter whose class is present in Funtestic::Persistence::ADAPTERS" do
        Funtestic.configuration.stub(:persistence).and_return(:cookie)
        Funtestic::Persistence::ADAPTERS.values.should include(subject.adapter)
      end

      it "should raise if the adapter cannot be found" do
        Funtestic.configuration.stub(:persistence).and_return(:something_weird)
        expect { subject.adapter }.to raise_error
      end
    end
    context "when the persistence config is a class" do
      let(:custom_adapter_class) { MyCustomAdapterClass = Class.new }
      it "should return that class" do
        Funtestic.configuration.stub(:persistence).and_return(custom_adapter_class)
        subject.adapter.should eq(MyCustomAdapterClass)
      end
    end
  end

end