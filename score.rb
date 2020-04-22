require 'active_record'
require 'pp'
require 'logger'

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection(
  "adapter" => "sqlite3",
  "database" => "./myapp.db"
)
# Modelを定義
class Score < ActiveRecord::Base
  validates :label, presence: true, length: { maximum: 40 }, uniqueness: true
end
