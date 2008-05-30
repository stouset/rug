module Git
  class StandardError      < ::StandardError; end
  
  class CorruptLooseObject <   StandardError; end
  class InvalidTreeEntry   <   StandardError; end
  class ObjectNotFound     <   StandardError; end
  class ObjectTypeError    <   StandardError; end
  class UnknownObjectError <   StandardError; end
end