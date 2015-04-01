class Analyse
  @type
  attr_accessor :type
  @@types = ["are you from","are you","where is","where are","when did","whose",'what is','who is','what are','who are','how are','how is','can you','can i','Do you','Have you','Had you','play some','play me','I want to','I really want to','how can it','calulate','tell me','define']
  def initialize question
    types.each do |known_question|
      if question.match(/known_question/i)
        @type = known_question
        p known_question
      else
        register_unkown_question question
        p known_question
      end
    end
  end
  private
  def register_unkown_question question
    @@types.push(question)
  end
end