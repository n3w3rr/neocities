# frozen_string_literal: true
require_relative './environment.rb'

describe Tempfile do
  it 'should return 0 when no data is written' do
    tmp = Tempfile.new
    tmp.write ''
    tmp.close
    _(tmp.size).must_equal 0
  end
end
