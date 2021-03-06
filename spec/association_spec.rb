require "spec_helper"
require "lookup_by"

describe ::ActiveRecord::Base do
  describe "macro methods" do
    subject { described_class }

    it { is_expected.to respond_to :lookup_for }
  end

  describe ".lookup_for" do
    subject { Address }

    it "doesn't clobber methods" do
      class << subject
        public :define_method, :remove_method
      end

      [:foo, :foo=, :raw_foo, :foo_before_type_cast, :foo?].each do |method|
        subject.define_method(method) { }

        expect { subject.lookup_for :foo }.to raise_error LookupBy::Error, /already exists/

        subject.remove_method(method)
      end

      class << subject.singleton_class
        public :define_method, :remove_method
      end

      [:with_foo, :with_foos].each do |method|
        subject.singleton_class.define_method(method) { }

        expect { subject.lookup_for :foo }.to raise_error LookupBy::Error, /already exists/

        subject.singleton_class.remove_method(method)
      end
    end

    it "requires a foreign key" do
      expect { subject.lookup_for :missing }.to raise_error LookupBy::Error, /foreign key/
    end

    it "rejects unsaved lookup values" do
      expect { subject.new.city = City.new(name: "Toronto") }.to raise_error ArgumentError, /must be saved/
    end

    it "requires the lookup model to be using lookup_by" do
      expect { subject.lookup_for :country }.to raise_error LookupBy::Error, /Country does not use lookup_by/
    end

    context "scope: nil" do
      it { is_expected.to respond_to(:with_city).with(1).arguments }
      it { is_expected.to respond_to(:with_cities).with(2).arguments }
    end

    context "scope: false" do
      it { is_expected.not_to respond_to(:with_postal_code) }
      it { is_expected.not_to respond_to(:with_postal_codes) }
    end

    it "better include the association under test in lookups" do
      expect(subject.lookups).to include(:city)
    end
  end
end

describe LookupBy::Association do
  before do
    City.create(name: "New York")
  end

  subject { Address.new }

  context "Address.lookup_for :city, strict: false" do
    it_behaves_like "a lookup for", :city

    it "accepts Integers" do
      subject.city = City.where(city: "New York").first.id
      expect(subject.city).to eq "New York"
    end

    it "rejects symbols" do
      expect { subject.city = :'New York' }.to raise_error ArgumentError
    end

    it "returns strings" do
      subject.city = "New York"
      expect(subject.city).to eq "New York"
    end

    it "allows missing values" do
      subject.city = "Chicago"
      expect(subject.city).to be_nil
    end
  end

  context "Address.lookup_for :state, symbolize: true" do
    it_behaves_like "a lookup for", :state

    it "allows symbols" do
      subject.state = :AL
      expect(subject.state).to eq :AL
    end

    it "returns symbols" do
      subject.state = "AL"
      expect(subject.state).to eq :AL
    end

    it "rejects missing values" do
      expect { subject.state = "FOO" }.to raise_error LookupBy::Error, /not in the .* lookup cache/
    end
  end

  context "Address.lookup_for :street" do
    it "accepts write-through values" do
      expect { subject.street = "Dearborn Street" }.to change(Street, :count)
    end
  end

  context "Missing.lookup_for :city" do
    it "does not raise foreign key error when table hasn't been created" do
      expect { require "missing" }.to_not raise_error
    end
  end
end
