module Git
  class StandardError      < ::StandardError; end
  class ObjectTypeError    <   StandardError; end
  class CorruptLooseObject <   StandardError; end
end