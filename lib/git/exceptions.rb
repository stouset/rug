module Git
  class StandardError   < ::StandardError; end
  class ObjectTypeError <   StandardError; end
  class CorruptSha1File <   StandardError; end
end