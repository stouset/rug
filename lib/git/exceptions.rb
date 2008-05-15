module Git
  class StandardError      < ::StandardError; end
  class CorruptLooseObject <   StandardError; end
  class InvalidTreeEntry   <   StandardError; end
  class ObjectTypeError    <   StandardError; end
end