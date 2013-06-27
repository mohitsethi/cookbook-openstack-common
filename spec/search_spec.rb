require_relative "spec_helper"
require ::File.join ::File.dirname(__FILE__), "..", "libraries", "search"

describe ::Openstack do
  before do
    @chef_run = ::ChefSpec::ChefRunner.new(::CHEFSPEC_OPTS) do |n|
      n.set["openstack"]["mq"] = {
        "server_role" => "openstack-ops-mq",
        "port" => 5672
      }
    end
    @chef_run.converge "openstack-common::default"
    @subject = ::Object.new.extend ::Openstack
  end

  describe "#search_for" do
    it "returns results" do
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:search).
        with(:node, "chef_environment:_default AND roles:role").
        and_return [[@chef_run.node], nil, nil]
      resp = @subject.search_for("role")

      expect(resp[0]['fqdn']).to eq "chefspec.local"
    end

    it "returns empty results" do
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:search).
        with(:node, "chef_environment:_default AND roles:empty-role").
        and_return [[], nil, nil]
      resp = @subject.search_for("empty-role")

      expect(resp).to eq []
    end
  end

  describe "#memcached_servers" do
    it "returns memcached list" do
      nodes = [
        { "memcached" => { "listen" => "1.1.1.1", "port" => "11211" }},
        { "memcached" => { "listen" => "2.2.2.2", "port" => "11211" }}
      ]
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:search_for).
        with("role").
        and_return nodes
      resp = @subject.memcached_servers("role")

      expect(resp).to eq ["1.1.1.1:11211", "2.2.2.2:11211"]
    end

    it "returns sorted memcached list" do
      nodes = [
        { "memcached" => { "listen" => "3.3.3.3", "port" => "11211" }},
        { "memcached" => { "listen" => "1.1.1.1", "port" => "11211" }},
        { "memcached" => { "listen" => "2.2.2.2", "port" => "11211" }}
      ]
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:search_for).
        with("role").
        and_return nodes
      resp = @subject.memcached_servers("role")

      expect(resp).to eq ["1.1.1.1:11211", "2.2.2.2:11211", "3.3.3.3:11211"]
    end

    it "returns memcached servers as defined by attributes" do
      nodes = {
        "openstack" => {
          "memcached_servers" => ["1.1.1.1:11211", "2.2.2.2:11211"]
        }
      }
      @subject.stub(:node).and_return @chef_run.node.merge nodes
      resp = @subject.memcached_servers("role")

      expect(resp).to eq ["1.1.1.1:11211", "2.2.2.2:11211"]
    end

    it "returns empty memcached servers as defined by attributes" do
      nodes = {
        "openstack" => {
          "memcached_servers" => []
        }
      }
      @subject.stub(:node).and_return @chef_run.node.merge nodes
      resp = @subject.memcached_servers("empty-role")

      expect(resp).to eq []
    end
  end

  describe "#rabbit_servers" do
    it "returns rabbit servers" do
      nodes = [
        { "openstack" => { "mq" => { "listen" => "1.1.1.1", "port" => "5672" }}},
        { "openstack" => { "mq" => { "listen" => "2.2.2.2", "port" => "5672" }}},
      ]
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:search_for).
        and_return nodes
      resp = @subject.rabbit_servers

      expect(resp).to eq "1.1.1.1:5672,2.2.2.2:5672"
    end

    it "returns sorted rabbit servers" do
      nodes = [
        { "openstack" => { "mq" => { "listen" => "3.3.3.3", "port" => "5672"  }}},
        { "openstack" => { "mq" => { "listen" => "1.1.1.1", "port" => "5672" }}},
        { "openstack" => { "mq" => { "listen" => "2.2.2.2", "port" => "5672"  }}}
      ]
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:search_for).
        and_return nodes
      resp = @subject.rabbit_servers

      expect(resp).to eq "1.1.1.1:5672,2.2.2.2:5672,3.3.3.3:5672"
    end

    it "returns rabbit servers when not searching" do
      node = @chef_run.node
      node.set["openstack"]["mq"]["servers"] = ["1.1.1.1", "2.2.2.2"]
      @subject.stub(:node).and_return @chef_run.node
      resp = @subject.rabbit_servers

      expect(resp).to eq "1.1.1.1:5672,2.2.2.2:5672"
    end
  end

  describe "#rabbit_server" do
    it "returns a rabbit server" do
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:rabbit_servers).
        and_return "1.1.1.1:5672"
      resp = @subject.rabbit_server

      expect(resp).to eq "1.1.1.1:5672"
    end

    it "returns a rabbit server when multiple servers returned" do
      @subject.stub(:node).and_return @chef_run.node
      @subject.stub(:rabbit_servers).
        and_return "1.1.1.1:5672,2.2.2.2:5672"
      resp = @subject.rabbit_server

      expect(resp).to eq "1.1.1.1:5672"
    end

    it "returns a rabbit server when not searching" do
      node = @chef_run.node
      node.set["openstack"]["mq"]["host"] = "1.1.1.1"
      @subject.stub(:node).and_return @chef_run.node
      resp = @subject.rabbit_server

      expect(resp).to eq "1.1.1.1:5672"
    end
  end
end