class Test
  def self.run commands
    system commands
  end
  Test.run gets.chomp
end